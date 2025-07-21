#!/bin/bash

#set -eo pipefail

# Script to process T1 images in a BIDS-formatted dataset with FreeSurfer's recon-all
# Author: Carolina Ferreira-Atuesta, Sept 2023
# Contact: cfatuesta@gmail.com

echo -e "FreeSurfer's recon-all BIDS Processing Script"
echo ""
echo "This script will:"
echo "- Run FreeSurfer's recon-all on all T1 images found in a BIDS dataset using multiple cores."
echo "- Create a quality control montage of the FreeSurfer output for each subject and session."
echo "- Extract the metrics into a CSV file."
echo "- Extract T1 metadata into a CSV file."
echo "- Run the longitudinal stream if there's more than one session per subject."
echo ""
echo "----------------------------------------------------------------------------------------"
echo "----------------------------------------------------------------------------------------"

echo "Note:"
echo -e "Make sure your dataset is organized according to the BIDS specification. This entails:\n"
echo "1. A main directory."
echo "2. Subdirectories for each subject labeled as 'sub-XXX'."
echo "3. Within each subject's directory, subdirectories for each session labeled as 'ses-XX'."
echo "4. Each session directory should contain an 'anat' subdirectory with the T1 image in nifti format named as 'sub-XXXXX_ses-XX_T1w.nii.gz'."
echo ""
echo "Also make sure you have the following scripts in your SUBJECTS_DIR path:"
echo "process_csv.py, merge_csv.py and process_longitudinal.py"
echo "Do not change the names of these scripts."
echo ""
echo "----------------------------------------------------------------------------------------"
echo "----------------------------------------------------------------------------------------"



echo -e "If your dataset isn't organized and named correctly, press Ctrl+C to exit."
echo "Otherwise, press enter to continue."
echo ""
echo ""
echo ""
echo ""
echo "Please DO NOT close this window until the script has finished."
echo ""
echo ""
echo ""
echo ""

# Dependency Checks
if ! command -v python3 &> /dev/null; then
    echo "Error: Python3 is not found. To install, type: brew install python3"
    exit 1
fi
if ! command -v freeview &> /dev/null; then
    echo "Error: FreeSurfer's freeview command is not found."
    exit 1
fi

if ! command -v magick &> /dev/null; then
    echo "Error: ImageMagick's magick command is not found. To install, type: brew install imagemagick"
    exit 1
fi

if ! command -v parallel &> /dev/null; then
    echo "Error: GNU Parallel is not found. To install, type: brew install parallel"
    exit 1
fi



# Prompt user for paths
if [ -z "$SUBJECTS_DIR" ]; then
    read -p "Enter the path to the SUBJECTS dataset: " SUBJECTS_DIR
else
    read -p "Enter the path to the SUBJECTS dataset [current path: $SUBJECTS_DIR - if this is OK, just press enter]: " NEW_SUBJECTS_DIR
    SUBJECTS_DIR=${NEW_SUBJECTS_DIR:-$SUBJECTS_DIR}
fi

if [ -z "$FREESURFER_HOME" ]; then
    read -p "Enter the path to Freesurfer installation: " FREESURFER_HOME
else
    read -p "Enter the path to Freesurfer installation [current path: $FREESURFER_HOME - if this is OK, just press enter]: " NEW_FREESURFER_HOME
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


echo ""
echo ""
echo "----------------------------------------------------------------------------------------"


# Display all T1s found
t1s_found=0
echo "Found the following T1 images:"
echo ""
echo ""
for subj in $SUBJECTS; do
    for session in ses-01 ses-02 ses-03; do
        T1="${SUBJECTS_DIR}/${subj}/${session}/anat/${subj}_${session}_T1w.nii" #or ending in .nii.g

        if [ ! -e "$T1" ]; then
            T1="${SUBJECTS_DIR}/${subj}/${session}/anat/${subj}_${session}_T1w.nii.gz"
            T1_path="${SUBJECTS_DIR}/${subj}/${session}/anat/"
        fi
        if [ -f "$T1" ]; then
            echo "$T1"
            (( t1s_found++ ))
            # Create array of T1s
            t1s_array+=("$T1")
        fi
    done
done

# Final message with the count
echo "Total T1s found: $t1s_found"
echo ""
echo ""

# Extracting metadata from the T1s
python3 "${SUBJECTS_DIR}/extract_metadata.py" "${t1s_array[@]}"



echo "Checking which T1s have not been processed through freesurfer..."
echo ""
echo ""
t1s_not_processed=()
t1s_without_montage=()

for subj in $SUBJECTS; do
    for session in ses-01 ses-02; do
        T1="${SUBJECTS_DIR}/${subj}/${session}/anat/${subj}_${session}_T1w.nii"
        if [ ! -e "$T1" ]; then
            T1="${SUBJECTS_DIR}/${subj}/${session}/anat/${subj}_${session}_T1w.nii.gz"
        fi
        if [ ! -f "$T1" ]; then
            continue
        fi

        log_path="${SUBJECTS_DIR}/${subj}/${session}/derivatives/${subj}/scripts/recon-all.log"
        montage_3d="${SUBJECTS_DIR}/${subj}/${session}/derivatives/qa-output/montage-3d.png"
        montage_2d="${SUBJECTS_DIR}/${subj}/${session}/derivatives/qa-output/montage-2d.png"

        if [ ! -f "$log_path" ] || ! grep -q "finished without error" "$log_path"; then
            t1s_not_processed+=("$T1")
        elif [ ! -f "$montage_3d" ] || [ ! -f "$montage_2d" ]; then
            t1s_without_montage+=("$T1")
        fi
    done
done

echo "Found ${#t1s_not_processed[@]} T1 images that have not been processed through freesurfer."
echo "Found ${#t1s_without_montage[@]} T1 images without montages."
echo ""
echo ""
echo ""

echo "Which pipeline do you want to use?"
echo "1) Classical FreeSurfer (recon-all)"
echo "2) FastSurfer (deep learning-based, much faster)"
read -p "Enter 1 or 2: " FS_CHOICE

if [[ "$FS_CHOICE" == "2" ]]; then
    USE_FASTSURFER=true
    if ! command -v fastsurfer.sh &> /dev/null; then
        echo "Error: FastSurfer not found. Ensure it's installed and in your PATH."
        exit 1
    fi
else
    USE_FASTSURFER=false
fi

if [[ "$FS_CHOICE" == "2" ]]; then
    USE_FASTSURFER=true

    # Check if fastsurfer.sh is installed
    if ! command -v fastsurfer.sh &> /dev/null; then
        echo "Error: FastSurfer is not installed or not in your PATH."
        echo "Install it from: https://github.com/Deep-MI/FastSurfer"
        exit 1
    fi

    # Check for required dependencies
    if ! command -v python3 &> /dev/null; then
        echo "Error: Python3 is required for FastSurfer."
        exit 1
    fi
    if ! python3 -c "import nibabel" &> /dev/null; then
        echo "Error: Python package 'nibabel' is missing. Install it via 'pip install nibabel'."
        exit 1
    fi
    if ! command -v mri_convert &> /dev/null; then
        echo "Error: FreeSurfer tools (like mri_convert) must still be installed and in your PATH."
        exit 1
    fi
    if ! python3 -c "import torch" &> /dev/null; then
        echo "Error: PyTorch is missing. Install it via 'pip install torch'."
        exit 1
    fi
    if ! python3 -c "import skimage" &> /dev/null; then
        echo "Error: skimage is missing. Install it via 'pip install scikit-image'."
        exit 1
    fi

    echo "FastSurfer and dependencies detected. Proceeding..."
else
    USE_FASTSURFER=false
fi


create_2d_slices() {
    local subj=$1
    local sub_path=$2
    local session=$3
    local output_dir=$4
    local cmd_file="$output_dir/freeview-commands-2d"

    echo $subj $sub_path $session $output_dir $cmd_file

    echo "-viewport coronal" > "$cmd_file"
    echo "-zoom 1.2" >> "$cmd_file"
    for n in $(seq 10 10 200); do
        echo "-slice 130 150 $n" >> "$cmd_file"
        echo "-ss $output_dir/frame-2d-coronal-$(printf '%03d' $n).png" >> "$cmd_file"
    done
    echo "-viewport axial" >> "$cmd_file"
    for n in $(seq 40 10 230); do
        echo "-slice 130 $n 132" >> "$cmd_file"
        echo "-ss $output_dir/frame-2d-axial-$(printf '%03d' $n).png" >> "$cmd_file"
    done
    echo "-quit" >> "$cmd_file"

    
    echo "Running freeview"
    echo ""
    echo ""
    freeview -v \
        "$sub_path/${session}/derivatives/${subj}/mri/T1.mgz" \
        "$sub_path/${session}/derivatives/${subj}/mri/aparc+aseg.mgz" \
        "$sub_path/${session}/derivatives/${subj}/mri/brainmask.mgz" \
        "$sub_path/${session}/derivatives/${subj}/mri/aseg.mgz:colormap=lut:opacity=0.2" \
        -f "$sub_path/${session}/derivatives/${subj}/surf/lh.white:edgecolor=blue" \
        "$sub_path/${session}/derivatives/${subj}/surf/lh.pial:edgecolor=red" \
        "$sub_path/${session}/derivatives/${subj}/surf/rh.white:edgecolor=blue" \
        "$sub_path/${session}/derivatives/${subj}/surf/rh.pial:edgecolor=red" \
        -cmd "$cmd_file"
    
    echo "Creating montage"
    echo ""
    echo ""
    magick montage "$output_dir/"frame-2d-*.png -tile 5x8 -geometry +0+0 "$output_dir/montage-2d.png"

    rm "$output_dir/"frame-2d-*.png
}

create_2d_slices_longitudinal() {
       local subj=$1
    local sub_path=$2
    local session=$3
    local output_dir=$4
    local cmd_file="$output_dir/freeview-commands-2d"

    echo $subj $sub_path $session $output_dir $cmd_file

    echo "-viewport coronal" > "$cmd_file"
    echo "-zoom 1.2" >> "$cmd_file"
    for n in $(seq 10 10 200); do
        echo "-slice 130 150 $n" >> "$cmd_file"
        echo "-ss $output_dir/frame-2d-coronal-$(printf '%03d' $n).png" >> "$cmd_file"
    done
    echo "-viewport axial" >> "$cmd_file"
    for n in $(seq 40 10 230); do
        echo "-slice 130 $n 132" >> "$cmd_file"
        echo "-ss $output_dir/frame-2d-axial-$(printf '%03d' $n).png" >> "$cmd_file"
    done
    echo "-quit" >> "$cmd_file"

    
    echo "Running freeview"
    echo ""
    echo ""
    freeview -v \
        "$sub_path/${session}/derivatives/longitudinal/${subj}/mri/T1.mgz" \
        "$sub_path/${session}/derivatives/longitudinal/${subj}/mri/aparc+aseg.mgz" \
        "$sub_path/${session}/derivatives/longitudinal/${subj}/mri/brainmask.mgz" \
        "$sub_path/${session}/derivatives/longitudinal/${subj}/mri/aseg.mgz:colormap=lut:opacity=0.2" \
        -f "$sub_path/${session}/derivatives/longitudinal/${subj}/surf/lh.white:edgecolor=blue" \
        "$sub_path/${session}/derivatives/longitudinal/${subj}/surf/lh.pial:edgecolor=red" \
        "$sub_path/${session}/derivatives/longitudinal/${subj}/surf/rh.white:edgecolor=blue" \
        "$sub_path/${session}/derivatives/longitudinal/${subj}/surf/rh.pial:edgecolor=red" \
        -cmd "$cmd_file"
    
    echo "Creating montage"
    echo ""
    echo ""
    magick montage "$output_dir/"frame-2d-*.png -tile 5x8 -geometry +0+0 "$output_dir/montage-2d.png"

    rm "$output_dir/"frame-2d-*.png
}


create_3d_slices() {
    local subj=$1
    local sub_path=$2
    local session=$3
    local output_dir=$4
    local cmd_file="$output_dir/freeview-commands-3d"

    echo "-viewport 3d" > "$cmd_file"
    echo "-hide-3d-frames" >> "$cmd_file"
    echo "-zoom 1.5" >> "$cmd_file"
    echo "-ss $output_dir/parc-3d-01-left.png" >> "$cmd_file"
    echo "-cam azimuth 90 " >> "$cmd_file"
    echo "-ss $output_dir/parc-3d-02-caudal.png" >> "$cmd_file"
    echo "-cam azimuth 90 " >> "$cmd_file"
    echo "-ss $output_dir/parc-3d-03-right.png" >> "$cmd_file"
    echo "-cam azimuth 90" >> "$cmd_file"
    echo "-ss $output_dir/parc-3d-04-rostral.png" >> "$cmd_file"
    echo "-cam azimuth 180 elevation 90" >> "$cmd_file"
    echo "-ss $output_dir/parc-3d-05-dorsal.png" >> "$cmd_file"
    echo "-cam elevation 180" >> "$cmd_file"
    echo "-ss $output_dir/parc-3d-06-ventral.png" >> "$cmd_file"
    echo "-quit" >> "$cmd_file"

    
    echo "Running freeview"
    echo ""
    echo ""
    freeview -v \
        "$sub_path/${session}/derivatives/${subj}/mri/brainmask.mgz" \
        -f "$sub_path/${session}/derivatives/${subj}/surf/lh.pial:annot=aparc.annot:name=pial_aparc:visible=1" \
        "$sub_path/${session}/derivatives/${subj}/surf/rh.pial:annot=aparc.annot:name=pial_aparc:visible=1" \
        -cmd "$cmd_file"
    
    echo "Creating montage"
    echo ""
    echo ""
    magick montage "$output_dir/"parc-3d-*.png -tile 3x2 -geometry +0+0 "$output_dir/montage-3d.png"

    # Delete the individual images and only keep the montage
    rm "$output_dir/"parc-3d-*.png
}

create_3d_slices_longitudinal() {
    local subj=$1
    local sub_path=$2
    local session=$3
    local output_dir=$4
    local cmd_file="$output_dir/freeview-commands-3d"

    echo "-viewport 3d" > "$cmd_file"
    echo "-hide-3d-frames" >> "$cmd_file"
    echo "-zoom 1.5" >> "$cmd_file"
    echo "-ss $output_dir/parc-3d-01-left.png" >> "$cmd_file"
    echo "-cam azimuth 90 " >> "$cmd_file"
    echo "-ss $output_dir/parc-3d-02-caudal.png" >> "$cmd_file"
    echo "-cam azimuth 90 " >> "$cmd_file"
    echo "-ss $output_dir/parc-3d-03-right.png" >> "$cmd_file"
    echo "-cam azimuth 90" >> "$cmd_file"
    echo "-ss $output_dir/parc-3d-04-rostral.png" >> "$cmd_file"
    echo "-cam azimuth 180 elevation 90" >> "$cmd_file"
    echo "-ss $output_dir/parc-3d-05-dorsal.png" >> "$cmd_file"
    echo "-cam elevation 180" >> "$cmd_file"
    echo "-ss $output_dir/parc-3d-06-ventral.png" >> "$cmd_file"
    echo "-quit" >> "$cmd_file"

    
    echo "Running freeview"
    echo ""
    echo ""
    freeview -v \
        "$sub_path/${session}/derivatives/longitudinal/${subj}/mri/brainmask.mgz" \
        -f "$sub_path/${session}/derivatives/longitudinal/${subj}/surf/lh.pial:annot=aparc.annot:name=pial_aparc:visible=1" \
        "$sub_path/${session}/derivatives/longitudinal/${subj}/surf/rh.pial:annot=aparc.annot:name=pial_aparc:visible=1" \
        -cmd "$cmd_file"
    
    echo "Creating montage"
    echo ""
    echo ""
    magick montage "$output_dir/"parc-3d-*.png -tile 3x2 -geometry +0+0 "$output_dir/montage-3d.png"

    # Delete the individual images and only keep the montage
    rm "$output_dir/"parc-3d-*.png
}

process_visualization() {
    local subj=$1
    local session=$2
    local sub_path="${SUBJECTS_DIR}/${subj}"
    local FREESURFER_OUT="${SUBJECTS_DIR}/${subj}/${session}/derivatives"
    local output_dir="${FREESURFER_OUT}/qa-output"
    
    echo "Processing $subj"
    [ ! -d "$output_dir" ] && mkdir -p "$output_dir"
    echo ""
    echo ""
    echo "Creating 2d slices"
    create_2d_slices "$subj" "$sub_path" "$session" "$output_dir"
    echo ""
    echo ""
    echo "Creating 3d slices"
    create_3d_slices "$subj" "$sub_path" "$session" "$output_dir"
    echo ""
    echo "" 
    # Printing the confirmation at the end
    echo "QA images for $subj printed"
    echo ""
    echo ""
}

process_visualization_longitudinal() {
    local subj=$1
    local session=$2
    local sub_path="${SUBJECTS_DIR}/${subj}"
    local FREESURFER_OUT="${SUBJECTS_DIR}/${subj}/${session}/derivatives/longitudinal"
    local output_dir="${FREESURFER_OUT}/qa-output"
    
    echo "Processing $subj"
    [ ! -d "$output_dir" ] && mkdir -p "$output_dir"
    echo ""
    echo ""
    echo "Creating 2d slices"
    create_2d_slices_longitudinal "$subj" "$sub_path" "$session" "$output_dir"
    echo ""
    echo ""
    echo "Creating 3d slices"
    create_3d_slices_longitudinal "$subj" "$sub_path" "$session" "$output_dir"
    echo ""
    echo "" 
    # Printing the confirmation at the end
    echo "QA images for $subj printed"
    echo ""
    echo ""
}
process_t1_without_visualization() {
    local t1_path="$1"
    local subj=$(echo "$t1_path" | grep -Eo 'sub-[a-zA-Z0-9]+' | head -n1)
    local session=$(echo "$t1_path" | grep -Eo 'ses-[a-zA-Z0-9]+' | head -n1)
    local FREESURFER_OUT="${SUBJECTS_DIR}/${subj}/${session}/derivatives"

    [ ! -d "$FREESURFER_OUT" ] && mkdir -p "$FREESURFER_OUT" 

    if [ -f "$t1_path" ]; then
        if [ "$USE_FASTSURFER" = true ]; then
            fastsurfer.sh --t1 "$t1_path" --sid "$subj" --sd "$FREESURFER_OUT" --parallel --fs_license "$FREESURFER_HOME/license.txt"
        else
            recon-all -i "$t1_path" -s "$subj" -all -qcache -sd "$FREESURFER_OUT"
        fi
        segmentHA_T1.sh "$subj"
    else
        echo "T1 file not found for $subj"
        echo ""
        echo ""
    fi
}
export -f process_t1_without_visualization  # Export the function so parallel can use it

process_longitudinal_without_visualization() {
    local t1_path="$1"
    local subj=$(echo "$t1_path" | grep -Eo 'sub-[a-zA-Z0-9]+' | head -n1)
    local session=$(echo "$t1_path" | grep -Eo 'ses-[a-zA-Z0-9]+' | head -n1)
    local FREESURFER_OUT="${SUBJECTS_DIR}/${subj}/${session}/derivatives/longitudinal"
    
    [ ! -d "$FREESURFER_OUT" ] && mkdir -p "$FREESURFER_OUT" 

    if [ -f "$t1_path" ]; then
        if [ "$USE_FASTSURFER" = true ]; then
            fastsurfer.sh --t1 "$t1_path" --sid "$subj" --sd "$FREESURFER_OUT" --parallel --fs_license "$FREESURFER_HOME/license.txt"
        else
            recon-all -i "$t1_path" -s "$subj" -all -qcache -sd "$FREESURFER_OUT"
        fi
        segmentHA_T1.sh "$subj"
    else
        echo "T1 file not found for $subj"
        echo ""
        echo ""
    fi
}

export -f process_longitudinal_without_visualization  # Export the function so parallel can use it

# If there are T1s that haven't been processed
if [ ${#t1s_not_processed[@]} -gt 0 ]; then
    read -p "Do you want to process these images through the cross-sectional pipeline? (yes/no): " PROCEED_CHOICE
    if [[ $PROCEED_CHOICE == "yes" ]]; then
        echo "Starting the cross-sectional pipeline..."
        echo ""
        echo ""

        # Run the process_t1_without_visualization function in parallel
        parallel process_t1_without_visualization ::: "${t1s_not_processed[@]}" 

        # If you wish to limit the number of simultaneous jobs, you can use the -j option with parallel, e.g., parallel -j 4 ... to use 4 cores.

        # After parallel processing, run process_visualization sequentially
        for t1_path in "${t1s_not_processed[@]}"; do
            local subj=$(echo "$t1_path" | grep -Eo 'sub-[a-zA-Z0-9]+' | head -n1)
            local session=$(echo "$t1_path" | grep -Eo 'ses-[a-zA-Z0-9]+' | head -n1)
            process_visualization "$subj" "$session"
        done
    fi
fi



# If there are T1s without montages
if [ ${#t1s_without_montage[@]} -gt 0 ]; then
    read -p "Do you want to generate montages for these images? (yes/no): " MONTAGE_CHOICE
    if [[ $MONTAGE_CHOICE == "yes" ]]; then
        echo "Generating montages..."
        echo ""
        echo ""

        for t1_path in "${t1s_without_montage[@]}"; do
            subj=$(echo "$t1_path" | grep -Eo 'sub-[a-zA-Z0-9]+' | head -n1)
            session=$(echo "$t1_path" | grep -Eo 'ses-[a-zA-Z0-9]+' | head -n1)
            FREESURFER_OUT="${SUBJECTS_DIR}/${subj}/${session}/derivatives"
            
            process_visualization "$subj" "$session" 
        done
    fi
fi

# Creating the tables will all the cross-sectional data
export SUBJECTS_DIR="$SUBJECTS_DIR"
# Create a list of all subjects in $SUBJECTS_DIR that have a stats folder
measures_folder="${SUBJECTS_DIR}/measures"
if [ ! -d "$measures_folder" ]; then
    mkdir "$measures_folder"
fi


# LONGITUDINAL PIPELINE

BASE_SUBJECTS_DIR="$SUBJECTS_DIR"

# Function to check if the subject has already been processed
is_already_processed() {
    local subject_dir="$1"
    local log_files=("$subject_dir"/*/derivatives/longitudinal/*/scripts/recon-all.log)
    for log_file in "${log_files[@]}"; do
        if [[ -f "$log_file" && $(grep -c "finished without error" "$log_file") -gt 0 ]]; then
            return 0
        fi
    done
    return 1
}

# Check if the user wants to proceed with the longitudinal pipeline
read -p "Do you want to process through the longitudinal pipeline? (yes/no): " LONGITUDINAL_CHOICE
if [[ $LONGITUDINAL_CHOICE == "yes" ]]; then
    # Collect subjects which haven't been processed yet
    subjects=()
    for subject_dir in "$BASE_SUBJECTS_DIR"/sub-*; do
        if [ -d "$subject_dir" ] && ! is_already_processed "$subject_dir"; then
            subjects+=("$subject_dir")
            echo "$subjects is missing longitudinal processing, running it now..."
        fi
    done
    
    # Use parallel to run each subject on a different core and generate the montages
    parallel -j+0 "python3 process_longitudinal.py {}" ::: "${subjects[@]}"

    # After parallel processing, run process_visualization_longitudinal sequentially
    for subject_dir in "${subjects[@]}"; do
        subj=$(echo "$subject_dir" | grep -Eo 'sub-[a-zA-Z0-9]+' | head -n1)
        session=$(echo "$subject_dir" | grep -Eo 'ses-[a-zA-Z0-9]+' | head -n1)
        process_visualization_longitudinal "$subj" "$session"
    done

fi


# Define paths for longitudinal outputs
log_path_long="${SUBJECTS_DIR}/${subj}/${session}/derivatives/longitudinal"
echo $log_path_long
montage_3d_long="${SUBJECTS_DIR}/${subj}/${session}/derivatives/longitudinal/qa-output/montage-3d.png"
montage_2d_long="${SUBJECTS_DIR}/${subj}/${session}/derivatives/longitudinal/qa-output/montage-2d.png"


# Create an empty array to keep track of T1s without longitudinal montages
t1s_without_montage_long=()
echo "Checking which T1s have been processed through the longitudinal pipeline but don't have montages..."
echo ""
echo ""

for subj in $SUBJECTS; do
    echo "Processing subject: $subj"
    for session in ses-01 ses-02; do
        echo "Session: $session"
        base_folder="${SUBJECTS_DIR}/${subj}/${session}/derivatives/longitudinal"
        
        # Check if base folder exists
        if [ ! -d "$base_folder" ]; then
            echo "Directory does not exist: $base_folder"
            continue
        fi

        # Search for recon-all.log files in the specified directory structure
        log_paths=$(find "$base_folder" -type f -name "recon-all.log" -path "*/scripts/recon-all.log")

        # Iterate through each found log file
        for log_path in $log_paths; do
            folder=$(dirname "$log_path")
            qa_output_folder="${folder}/../qa-output"

            # Create qa-output folder if it doesn't exist
            if [ ! -d "$qa_output_folder" ]; then
                mkdir -p "$qa_output_folder"
            fi

            montage_3d_long="${qa_output_folder}/montage-3d.png"
            montage_2d_long="${qa_output_folder}/montage-2d.png"

            if grep -q "finished without error" "$log_path"; then
                if [ ! -f "$montage_3d_long" ] || [ ! -f "$montage_2d_long" ]; then
                    t1s_without_montage_long+=("$log_path")
                    echo "These T1s have been processed through the longitudinal pipeline but don't have montages:"
                    echo "$log_path"
                    echo ""
                    echo ""
                fi
            else
                echo "The processing did not finish without error for log file: $log_path"
                echo ""
                echo ""
            fi
        done
    done
done

if [ ${#t1s_without_montage_long[@]} -ne 0 ]; then
    echo "Summary of T1s without montages:"
    for t1 in "${t1s_without_montage_long[@]}"; do
        echo "$t1"
        echo ""
        echo ""
        
    done
fi


# If there are T1s processed through the longitudinal pipeline but without montages
if [ ${#t1s_without_montage_long[@]} -gt 0 ]; then
    read -p "Do you want to generate montages for these longitudinal outputs? (yes/no): " MONTAGE_CHOICE
    if [[ $MONTAGE_CHOICE == "yes" ]]; then
        echo "Generating montages..."
        echo ""
        echo ""

        for log_path in "${t1s_without_montage_long[@]}"; do
            # The directory containing the recon-all.log file
            recon_all_dir=$(dirname "$log_path")

            # Assuming the structure: {subject}/{session}/derivatives/longitudinal/{any folder}/scripts/recon-all.log
            # Extract subject and session information from the directory structure
            subj=$(echo "$recon_all_dir" | awk -F'/' '{print $(NF-5)}')
            session=$(echo "$recon_all_dir" | awk -F'/' '{print $(NF-4)}')

            if [ -z "$subj" ] || [ -z "$session" ]; then
                echo "Could not extract subject/session information from log path: $log_path"
                continue
            fi

            echo "Processing visualizations for $subj, $session"
            FREESURFER_OUT_LONG="${SUBJECTS_DIR}/${subj}/${session}/derivatives/longitudinal"
            
            process_visualization_longitudinal "$subj" "$session" 
        done
    fi
fi


echo "Extracting longitudinal data into csv files..."
echo ""
echo ""

# Assuming you have a specific directory structure for longitudinal data, modify the path accordingly
list="${BASE_SUBJECTS_DIR}/*/*/derivatives/*"
list_long="${BASE_SUBJECTS_DIR}/*/*/derivatives/longitudinal/*"
measures_folder="${BASE_SUBJECTS_DIR}/measures"


asegstats2table --subjects $list  --meas volume --skip --statsfile wmparc.stats --all-segs --tablefile $measures_folder/wmparc_stats.csv
asegstats2table --subjects $list  --meas volume --skip --statsfile aseg.stats --all-segs --tablefile $measures_folder/aseg_stats.csv
aparcstats2table --subjects $list  --hemi lh --meas volume --skip  --tablefile $measures_folder/aparc_volume_lh.csv
aparcstats2table --subjects $list  --hemi lh --meas thickness --skip  --tablefile $measures_folder/aparc_thickness_lh.csv
aparcstats2table --subjects $list  --hemi rh --meas volume --skip --tablefile $measures_folder/aparc_volume_rh.csv
aparcstats2table --subjects $list  --hemi rh --meas thickness --skip  --tablefile $measures_folder/aparc_thickness_rh.csv
asegstats2table --subjects $list  --skip --statsfile=hipposubfields.lh.T1.v21.stats --tablefile=$measures_folder/hipposubfields_lh.csv 
asegstats2table  --subjects $list  --skip --statsfile=hipposubfields.rh.T1.v21.stats --tablefile=$measures_folder/hipposubfields_rh.csv
asegstats2table --subjects $list  --skip --statsfile=amygdalar-nuclei.lh.T1.v21.stats --tablefile=$measures_folder/amyg_nuclei_lh.csv
asegstats2table  --subjects $list  --skip --statsfile=amygdala-nuclei.rh.T1.v21.stats --tablefile=$measures_folder/amyg_nuclei_rh.csv

asegstats2table --subjects $list_long --meas volume --skip --statsfile wmparc.stats --all-segs --tablefile $measures_folder/long_wmparc_stats.csv
asegstats2table --subjects $list_long   --meas volume --skip --statsfile aseg.stats --all-segs --tablefile $measures_folder/long_aseg_stats.csv
aparcstats2table --subjects $list_long   --hemi lh --meas volume --skip  --tablefile $measures_folder/long_aparc_volume_lh.csv
aparcstats2table --subjects $list_long   --hemi lh --meas thickness --skip  --tablefile $measures_folder/long_aparc_thickness_lh.csv
aparcstats2table --subjects $list_long   --hemi rh --meas volume --skip --tablefile $measures_folder/long_aparc_volume_rh.csv
aparcstats2table --subjects $list_long   --hemi rh --meas thickness --skip  --tablefile $measures_folder/long_aparc_thickness_rh.csv
asegstats2table --subjects $list_long   --skip --statsfile=hipposubfields.lh.T1.v21.stats --tablefile=$measures_folder/long_hipposubfields_lh.csv 
asegstats2table  --subjects $list_long   --skip --statsfile=hipposubfields.rh.T1.v21.stats --tablefile=$measures_folder/long_hipposubfields_rh.csv
asegstats2table --subjects $list_long   --skip --statsfile=amygdalar-nuclei.lh.T1.v21.stats --tablefile=$measures_folder/long_amyg_nuclei_lh.csv
asegstats2table  --subjects $list_long   --skip --statsfile=amygdala-nuclei.rh.T1.v21.stats --tablefile=$measures_folder/long_amyg_nuclei_rh.csv
echo "Done extracting longitudinal data into csv files."


# Find all csv files in $measures_folder
csv_files=$(find $measures_folder -type f -name "*.csv")
for csv_file in $csv_files; do
    python3 process_csv.py $csv_file
done


# For all files in $measures_folder, merge them by sub and ses and save them in the same folder as all_measures.csv
python3 merge_csv.py $measures_folder
echo ""
echo ""
echo ""
echo ""
echo "All done, you can close this window now."
echo ""
echo ""
echo ""
echo ""



