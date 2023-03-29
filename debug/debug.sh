#!/bin/bash

cd devcontainer-features
rm -rf .devcontainer/cloud-native

cp -ar src/cloud-native .devcontainer/

cd ~
devcontainer up --workspace-folder devcontainer-features/