#!/bin/bash

### BEGIN PARAMS
if [ -z "$Y_BUILD" ]
then
	echo "Need to specify the buildId of a Y-Build"
	exit 1
fi
if [ -z "$SDKTIMESTAMP" ]
then
	echo "Need to specify the timestamp of the SDK to build against"
	exit 1
fi
if [ -z "$JDT_VERSION_MAX" ]
then
	echo "Need to specify the maximum JDT version to which this patch should be applicable"
	exit 1
fi

SDKTAG=${SDKTAG:="I${SDKTIMESTAMP}"}
SDKVERSION=${SDKVERSION:=${SDKTAG}}
SDKFILE=eclipse-SDK-${SDKVERSION}-linux-gtk-x86_64.tar.gz
DROPS_DIR=${DROPS_DIR:=${SDKVERSION}}
SDKURL=https://download.eclipse.org/eclipse/downloads/drops4/${DROPS_DIR}/${SDKFILE}
# range of versions of org.eclipse.jdt.feature.group to which the result should be applicable:
JDT_VERSION_RANGE=${JDT_VERSION_RANGE:="[3.20.100.v${SDKTIMESTAMP},${JDT_VERSION_MAX})"}
### END PARAMS

## (1) Download and extract a specified Eclipse SDK
if [ ! -e ${SDKFILE} ]
then
	wget -nv ${SDKURL}
fi
if [ ! -x eclipse/eclipse ]
then
	tar xzf ${SDKFILE}
fi

## Locations & Files:
BASE=`pwd`
ECLIPSE=${BASE}/eclipse
LAUNCHER=`ls ${ECLIPSE}/plugins/org.eclipse.equinox.launcher_*.jar`
PDEBUILD=`ls -d ${ECLIPSE}/plugins/org.eclipse.pde.build_*`

TIMESTAMP=`date +"%Y%m%d-%H%M"`


## Prepare work clean area:
if [ -e work ]
then
	/bin/rm -r work/*
else
	mkdir work
fi

## 2. Perform some string substitutions to feed build values into text files for the next step
cat src/feature.xml.in | sed -e "s|SDKTIMESTAMP|${SDKTIMESTAMP}|" > src/org.eclipse.jdt.javanextpatch/feature.xml
cat builder/build.properties.in | sed -e "s|BASEDIR|${BASE}|g;s/TIMESTAMP/${TIMESTAMP}/g" > builder/build.properties
cat maps/jdtpatch.map.in | sed -e "s|BASEDIR|${BASE}|g;s|Y_BUILD|${Y_BUILD}|g" > maps/jdtpatch.map
cp maps/jdtpatch.map work/directory.txt

cd work
mkdir buildRepo

## 3. Invoke PDE Build on just the patch feature
java -jar ${LAUNCHER} -nosplash \
	-application org.eclipse.ant.core.antRunner \
	-buildfile ${PDEBUILD}/scripts/build.xml \
	-Dbuilder=${BASE}/builder \
	-DbuildDirectory=${BASE}/work \
	-Dmap.file.path=${BASE}/maps/jdtpatch.map
	
echo "Created content:"
ls -lR buildRepo
	
cd ${BASE}

## 4. Add missing files (feature.properties, license.html) into the generated feature jar
cd src/org.eclipse.jdt.javanextpatch
jar -uvf ${BASE}/work/buildRepo/features/org.eclipse.jdt.javanextpatch_* feature.properties license.html
ls -l ${BASE}/work/buildRepo/features
cd -

## 5. Sign the feature jar:
mkdir work/signed
cd work/buildRepo/features
JAR=`ls org.eclipse.jdt.javanextpatch_*.jar`
echo "feature jar is ${JAR}"
curl -o ${BASE}/work/signed/${JAR} -F file=@${JAR} https://cbi.eclipse.org/jarsigner/sign
ls -l . ${BASE}/work/signed
cp ${BASE}/work/signed/${JAR} .
cd -

# 6. Add general metadata (generate from buildRepo to buildRepo2):
${BASE}/eclipse/eclipse -nosplash -application org.eclipse.equinox.p2.publisher.FeaturesAndBundlesPublisher \
	-artifactRepository file:${BASE}/work/buildRepo2 \
	-metadataRepository file:${BASE}/work/buildRepo2 \
	-source ${BASE}/work/buildRepo

ls -l work/buildRepo2

## 7. Add category metadata
${BASE}/eclipse/eclipse -nosplash -application org.eclipse.equinox.p2.publisher.CategoryPublisher \
	-metadataRepository file:${BASE}/work/buildRepo2 \
	-categoryDefinition file:${BASE}/src/category.xml 
ls -l work/buildRepo2

## 8. Tweak the version range, to make the patch applicable to more than just one specific build
cd work/buildRepo2
mv content.xml content-ORIG.xml
# this would work without ant, but xsltproc is not found on the build server
#xsltproc --nonet --nowrite \
#	--stringparam patchFeatureVersionRange "${JDT_VERSION_RANGE}" \
#	--stringparam patchFeatureIU org.eclipse.jdt.javanextpatch.feature.group ${BASE}/patchMatchVersion.xsl \
#	content-ORIG.xml > content.xml
ant -f ${BASE}/patchMatchVersion.xml -DpatchFeatureVersionRange="${JDT_VERSION_RANGE}" -DBASE=${BASE} -DREPODIR=${BASE}/work/buildRepo2
ls -l


## 9. Jar up the metadata and zip the full result
jar cf content.jar content.xml
jar cf artifacts.jar artifacts.xml
zip -r ${BASE}/work/org.eclipse.jdt.javanextpatch.zip features plugins *.jar
cd -

## 10. Rename the repo, create a composite repo and upload everything to the download site:
cd work
if [ ! -e buildRepo2 ]
then
	echo "Repository was not created"
	exit 1
fi

mv buildRepo2 P${TIMESTAMP}
/bin/rm artifacts.jar content.jar
cp ../build_composite.xml .
java -jar ${LAUNCHER} -nosplash -application org.eclipse.ant.core.antRunner -f build_composite.xml -Dchild=P${TIMESTAMP}
ls -l
scp -r P${TIMESTAMP} composite*.xml genie.jdt@projects-storage.eclipse.org:/home/data/httpd/download.eclipse.org/jdt/updates/4.35-P-builds

