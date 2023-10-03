import os
import json as js
import re
import pandas as pd
import sys

# Extract paths from command-line arguments
t1s_path_array = sys.argv[1:]

# Assuming df is predefined, if not, initialize it
df = pd.DataFrame(columns=['sub', 'ses', 'mrtype', 'description', 'thickness', 'sar', 'TE', 'TR', 'flip', 'direction', 'field_strength'])

for nii_file_path in t1s_path_array:
    root = os.path.dirname(nii_file_path)
    json_file = None
    
    try:
        for file in os.listdir(root):
            if file.endswith('.json'):
                json_file = file
                break
        
        if json_file:
            json_file_path = os.path.join(root, json_file)
            
            with open(json_file_path, encoding='utf-8') as f:
                if f.read(1):  
                    f.seek(0)
                    print(f"Reading JSON from: {json_file_path}")
                    data = js.load(f)
                else:
                    print(f"File {json_file_path} is empty.")
                    continue  # Skip to the next iteration if the file is empty
    except UnicodeDecodeError:
        print(f"Could not read file {json_file_path} due to encoding issues.")
        continue  # Skip to the next iteration if there's an encoding issue
    except json.JSONDecodeError:
        print(f"Could not decode JSON from file {json_file_path}.")
        continue  # Skip to the next iteration if JSON decoding fails

    with open(json_file_path, encoding='ISO-8859-1') as f:

        data = js.load(f)
        sub = re.findall(r'(sub-[a-zA-Z0-9]+)', root)[0]
        ses = re.findall(r'(ses-[a-zA-Z0-9]+)', root)[0]
        mrtype = data.get('MRAcquisitionType', '')
        description = data.get('SeriesDescription', '')
        thickness = data.get('SliceThickness', '')
        sar = data.get('SAR', '')
        TE = data.get('EchoTime', '')
        TR = data.get('RepetitionTime', '')
        flip = data.get('FlipAngle', '')
        direction = data.get('ImageOrientationPatientDICOM', '')
        field_strength = data.get('MagneticFieldStrength', None)

        d = {'sub': sub, 'ses': ses, 'mrtype': mrtype, 'description': description, 'thickness': thickness, 'sar': sar, 'TE': TE, 'TR': TR, 'flip': flip, 'direction': direction, 'field_strength': field_strength}
        df = pd.concat([df, pd.DataFrame([d])], ignore_index=True)


# Save the DataFrame to a CSV file named "T1_metadata.csv" inside the current working directory
df.to_csv('T1_metadata.csv', index=False)

