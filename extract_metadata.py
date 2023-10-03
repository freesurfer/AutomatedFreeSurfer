import os
import json as js
import re
import pandas as pd
import sys

# Extract paths from command-line arguments
t1s_found = sys.argv[1:]

# Assuming df is predefined, if not, initialize it
df = pd.DataFrame(columns=['sub', 'ses', 'mrtype', 'description', 'thickness', 'sar', 'TE', 'TR', 'flip', 'direction', 'field_strength'])

# The rest of your script remains largely the same
for nii_file_path in t1s_found:
    root = os.path.dirname(nii_file_path)

    json_file = None
    for file in os.listdir(root):
        if file.endswith('.json'):
            json_file = file
            break
    
    if json_file:
        json_file_path = os.path.join(root, json_file)

        with open(json_file_path) as f:
            data = js.load(f)
            sub = re.findall(r'(sub-[a-zA-Z0-9]+)', root)[0]
            ses = re.findall(r'(ses-[a-zA-Z0-9]+)', root)[0]
            mrtype = data['MRAcquisitionType']
            description = data['SeriesDescription']
            thickness = data['SliceThickness']
            sar = data['SAR']
            TE = data['EchoTime']
            TR = data['RepetitionTime']
            flip = data['FlipAngle']
            direction = data['ImageOrientationPatientDICOM']
            field_strength = data('MagneticFieldStrength', None)

            d = {'sub': sub, 'ses': ses, 'mrtype': mrtype, 'description': description, 'thickness': thickness, 'sar': sar, 'TE': TE, 'TR': TR, 'flip': flip, 'direction': direction, 'MagneticFieldStrength': field_strength}
            df = df.append(d, ignore_index=True)

# Save the DataFrame to a CSV file named "T1_metadata.csv" inside the current working directory
df.to_csv('T1_metadata.csv', index=False)

