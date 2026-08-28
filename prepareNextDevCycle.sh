#!/bin/bash -xeu

#*******************************************************************************
# Copyright (c) 2026 Hannes Wellmann and others.
#
# This program and the accompanying materials
# are made available under the terms of the Eclipse Public License 2.0
# which accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Contributors:
#     Hannes Wellmann - initial API and implementation
#*******************************************************************************

# This script is called by the pipeline for preparing the next development cycle (this file's name is crucial!)
# and applies the changes required individually for JDT.
# The calling pipeline also defines environment variables usable in this script.

# Update the link to the migration guide
migrationContentFile='org.eclipse.jdt/intro/migrateExtensionContent.xml'
sed -i "${migrationContentFile}" \
	--expression "s|${PREVIOUS_RELEASE_VERSION//./\\.}|${NEXT_RELEASE_VERSION}|g"
sed -i "${migrationContentFile}" \
	--expression "s|${PREVIOUS_RELEASE_VERSION//./_}|${NEXT_RELEASE_VERSION//./_}|g"

git commit --all --message "Migration Guide update - Eclipse ${NEXT_RELEASE_VERSION}"
