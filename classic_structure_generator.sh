#!/bin/bash

# Prompt user for paths
if [ -z "$SUBJECTS_DIR" ]; then
    read -p "Enter the path to the SUBJECTS dataset: " SUBJECTS_DIR
else
    read -p "Enter the path to the SUBJECTS dataset [current path: $SUBJECTS_DIR - if this is OK, just click enter]: " NEW_SUBJECTS_DIR
    SUBJECTS_DIR=${NEW_SUBJECTS_DIR:-$SUBJECTS_DIR}
fi

if [ -z "$FREESURFER_HOME" ]; then
    read -p "Enter the path to Freesurfer installation: " FREESURFER_HOME
else
    read -p "Enter the path to Freesurfer installation [current path: $FREESURFER_HOME - if this is OK, just click enter]: " NEW_FREESURFER_HOME
    FREESURFER_HOME=${NEW_FREESURFER_HOME:-$FREESURFER_HOME}
fi

# Check if paths exist
for path in "$SUBJECTS_DIR" "$FREESURFER_HOME"; do
    if [ ! -d "$path" ]; then
        echo "Error: $path does not exist or is not a directory."
        exit 1
    fi
done

# Set FREESURFER_HOME and source the setup script
export FREESURFER_HOME
source "$FREESURFER_HOME/SetUpFreeSurfer.sh"

# List all subjects in the SUBJECTS dataset
SUBJECTS=$(ls "$SUBJECTS_DIR" | grep -Eo 'sub-[a-zA-Z0-9]+')

# Create the classic_structure directory if it doesn't exist
classic_structure_dir="${SUBJECTS_DIR}/classic_structure"
if [ ! -d "${classic_structure_dir}" ]; then
    mkdir "${classic_structure_dir}"
fi

# Generate symlinks for Freesurfer outputs
for subject in $SUBJECTS; do
    for session in "ses-01" "ses-02"; do
        source_path="${SUBJECTS_DIR}/${subject}/${session}/anat"
        symlink_path="${classic_structure_dir}/${subject}_${session}"
        
        if [ -d "${source_path}" ]; then
            if [ ! -L "${symlink_path}" ]; then
                ln -s "${source_path}" "${symlink_path}"
                echo "Symlink created: ${symlink_path} -> ${source_path}"
            else
                echo "Symlink ${symlink_path} already exists. Skipping."
            fi
        else
            echo "Source path ${source_path} does not exist. Skipping."
        fi
    done
done
