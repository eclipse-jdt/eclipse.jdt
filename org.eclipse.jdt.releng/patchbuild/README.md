# Overview of Steps
The following steps are orchestrated in [build.sh](https://github.com/eclipse-jdt/eclipse.jdt/blob/BETA_JAVA25/org.eclipse.jdt.releng/patchbuild/build.sh) :

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
    * uses [patchMatchVersion.xsl](https://github.com/eclipse-jdt/eclipse.jdt/blob/BETA_JAVA25/org.eclipse.jdt.releng/patchbuild/patchMatchVersion.xsl) as copied from releng
    * not finding `xsltproc` on the build machine, this transformation had to be wrapped in an ant build, see [patchMatchVersion.xml](https://github.com/eclipse-jdt/eclipse.jdt/blob/BETA_JAVA25/org.eclipse.jdt.releng/patchbuild/patchMatchVersion.xml)
9. jar up the metadata and zip the full result (for easier consumption until we push content to download).
10. rename the repo, create a composite repo and upload everything to the download site:

Numbers in this list are reflected in the script.

## Building the feature (step 3)

PDE Build is set up using these files (`.in` indicates that the file is subject to string substitutions):
* [builder/build.properties.in](https://github.com/eclipse-jdt/eclipse.jdt/blob/BETA_JAVA25/org.eclipse.jdt.releng/patchbuild/builder/build.properties.in).
     * a few general configuration options for the build
* [src/org.eclipse.jdt.javanextpatch](https://github.com/eclipse-jdt/eclipse.jdt/tree/BETA_JAVA25/org.eclipse.jdt.releng/patchbuild/src/org.eclipse.jdt.javanextpatch)/* + [src/feature.xml.in](https://github.com/eclipse-jdt/eclipse.jdt/blob/BETA_JAVA25/org.eclipse.jdt.releng/patchbuild/src/feature.xml.in)
     * the actual feature definition (nothing special here)
* [maps/jdtpatch.map.in](https://github.com/eclipse-jdt/eclipse.jdt/blob/BETA_JAVA25/org.eclipse.jdt.releng/patchbuild/maps/jdtpatch.map.in)
     * this one (after string substitution) declares where elements are to be fetched from:
       * plugins as p2 installable units from the Y-Build URL
       * the feature by copying from the above source folder
* [src/category.xml](https://github.com/eclipse-jdt/eclipse.jdt/blob/BETA_JAVA25/org.eclipse.jdt.releng/patchbuild/src/category.xml)  
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

# Updating for a new version

## User facing text
The following files contain strings like "Java 25", which need to be updated to the correct version with or without the "(BETA)" suffix.
* [build_composite.xml](https://github.com/eclipse-jdt/eclipse.jdt/blob/BETA_JAVA25/org.eclipse.jdt.releng/patchbuild/build_composite.xml)
* [builder/build.properties.in](https://github.com/eclipse-jdt/eclipse.jdt/blob/BETA_JAVA25/org.eclipse.jdt.releng/patchbuild/builder/build.properties.in)
* [src/org.eclipse.jdt.javanextpatch/feature.properties](https://github.com/eclipse-jdt/eclipse.jdt/blob/BETA_JAVA25/org.eclipse.jdt.releng/patchbuild/src/org.eclipse.jdt.javanextpatch/feature.properties)
* [src/category.xml](https://github.com/eclipse-jdt/eclipse.jdt/blob/BETA_JAVA25/org.eclipse.jdt.releng/patchbuild/src/category.xml)

## Plugins and versions
The following files must be kept in sync with actual plugins in the Y-build to consume:
* [src/feature.xml.in](https://github.com/eclipse-jdt/eclipse.jdt/blob/BETA_JAVA25/org.eclipse.jdt.releng/patchbuild/src/feature.xml.in) -- which plugins to include in the patch
  * Addtionally in this file the version of the feature itself should be adjusted to the targetted Java version:
* [maps/jdtpatch.map.in](https://github.com/eclipse-jdt/eclipse.jdt/blob/BETA_JAVA25/org.eclipse.jdt.releng/patchbuild/maps/jdtpatch.map.in) -- where to find plugins


# Expected warnings during the build

Warnings like the following can be ignored:
* `[eclipse.fetch] The entry plugin@org.eclipse.jdt.core,3.42.150.qualifier has not been found. The entry plugin@org.eclipse.jdt.core has been used instead.`

# Trouble Shooting

Things most likely go wrong during the first ant build, under the heading **generateScript:**

This step requires that the following are consistent with each other: plugins in the reference Y-build, entries in `feature.xml.in` (what to include) and entries in `jdtpatch.map.in` (where to find it).

* Error like `[eclipse.fetch] Missing directory entry: plugin@org.eclipse.jdt.debug,3.23.150.qualifier.`
   * this indicates that the file `patchbuild/maps/jdtpatch.map.in` is incomplete
* Error like `Unable to find plug-in: org.eclipse.jdt.launching_3.23.350.qualifier.`
   * likely a version inconsistency between an entry in `patchbuild/src/feature.xml.in` and the actual plugin
   
