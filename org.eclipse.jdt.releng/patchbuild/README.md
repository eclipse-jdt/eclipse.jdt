# Overview of Steps
The following steps are orchestrated in [build.sh](https://github.com/eclipse-jdt/eclipse.jdt/blob/BETA_JAVA24/org.eclipse.jdt.releng/patchbuild/build.sh) :

1. download and extract a specified Eclipse SDK
    * this will drive individual build steps below
2. perform some string substitutions to feed build values into text files for the next step
3. invoke **PDE Build** on just the patch feature
    * this pulls included plugins from the specified Y-build
4. add missing files (feature.properties, license.html) into the generated feature jar (PDE Build drops these for unknown reasons)
5. sign the feature jar (plugins are already signed from the Y-build)
6. re-generate metadata using p2's **FeaturesAndBundlesPublisher**
7. generate the category using p2's **CategoryPublisher**
8. tweak the version range, to make the patch applicable to more than just one specific build
    * uses [patchMatchVersion.xsl](https://github.com/eclipse-jdt/eclipse.jdt/blob/BETA_JAVA24/org.eclipse.jdt.releng/patchbuild/patchMatchVersion.xsl) as copied from releng
    * not finding `xsltproc` on the build machine, this transformation had to be wrapped in an ant build, see [patchMatchVersion.xml](https://github.com/eclipse-jdt/eclipse.jdt/blob/BETA_JAVA24/org.eclipse.jdt.releng/patchbuild/patchMatchVersion.xml)
9. jar up the metadata and zip the full result (for easier consumption until we push content to download).
10. rename the repo, create a composite repo and upload everything to the download site:

Numbers in this list are reflected in the script.

## Building the feature (step 3)

PDE Build is set up using these files (`.in` indicates that the file is subject to string substitutions):
* [builder/build.properties.in](https://github.com/eclipse-jdt/eclipse.jdt/blob/BETA_JAVA24/org.eclipse.jdt.releng/patchbuild/builder/build.properties.in).
     * a few general configuration options for the build
* [src/org.eclipse.jdt.javanextpatch](https://github.com/eclipse-jdt/eclipse.jdt/tree/BETA_JAVA24/org.eclipse.jdt.releng/patchbuild/src/org.eclipse.jdt.javanextpatch)/* + [src/feature.xml.in](https://github.com/eclipse-jdt/eclipse.jdt/blob/BETA_JAVA24/org.eclipse.jdt.releng/patchbuild/src/feature.xml.in)
     * the actual feature definition (nothing special here)
* [maps/jdtpatch.map.in](https://github.com/eclipse-jdt/eclipse.jdt/blob/BETA_JAVA24/org.eclipse.jdt.releng/patchbuild/maps/jdtpatch.map.in)
     * this one (after string substitution) declares where elements are to be fetched from:
       * plugins as p2 installable units from the Y-Build URL
       * the feature by copying from the above source folder
* [src/category.xml](https://github.com/eclipse-jdt/eclipse.jdt/blob/BETA_JAVA24/org.eclipse.jdt.releng/patchbuild/src/category.xml)  
     * the category definition just like normal.

## Generating Metadata (steps 6 & 7)

The challenge here was to get all of the below reflected in the generated metadata:
* version substitutions as performed by PDE Build
    * this required to use the feature as produced by PDE Build rather than the exploded source version
* checksum of the feature jar
    * also this requires to use the binary feature
* string substitutions using `feature.properties`
    * was missing in the binary feature, but this was solved by updating the jar in step 4

The final trick is that FeaturesAndBundlesPublisher must also copy everything into a new location, as otherwise it would either append to metadata from step 3 or wipe out all artifacts before starting. Hence we have
* `work/buildRepo` -- result from step 3
* `work/buildRepo2` -- result from step 6

The CategoryPublisher had no such issues, it will update the previous result inline.


