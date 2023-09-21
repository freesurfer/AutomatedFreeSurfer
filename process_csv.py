# process_csv.py

import sys
import pandas as pd

def main():
    if len(sys.argv) != 2:
        print("Usage: python process_csv.py <path_to_csv>")
        sys.exit(1)

    csv_file = sys.argv[1]

    # open the file and chnage it to excel format
    df = pd.read_csv(csv_file, sep='\t')

    #change the first column name to subject
    df.rename(columns={df.columns[0]: 'subject'}, inplace=True)
    

    #from the first column, find the sub- and ses- for each row and put them in a new column, the sub can have lettters and numbers
    df['sub'] = df['subject'].str.extract(r'(sub-[a-zA-Z0-9]+)')
    df['ses'] = df['subject'].str.extract(r'(ses-[a-zA-Z0-9]+)')

    #create a new column named pipeline, and if the rows in the first column has a "long" then put "longitudinal" in the new column, if it doenst have "_base" and "long" then put "cross-sectional" in the new column, otherwise put "base" in the new column
    df['pipeline'] = df['subject'].apply(lambda x: 'longitudinal' if 'long' in x else 'cross-sectional' if '_base' not in x and 'long' not in x else 'base')

    # move the sub and ses columns to the front
    cols = df.columns.tolist()
    cols = cols[-3:] + cols[:-3]
    df = df[cols]

    #delete the subject column
    df.drop('subject', axis=1, inplace=True)
    #save the new csv file with the same name
    df.to_csv(csv_file, sep='\t', index=False)

    


if __name__ == "__main__":
    main()
