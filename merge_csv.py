import pandas as pd
import os
import sys

def merge_csv_files(folder_path):
    # List all files in the given folder
    all_files = [os.path.join(folder_path, f) for f in os.listdir(folder_path) if f.endswith('.csv')]

    if not all_files:
        print("No CSV files found in the specified folder.")
        return

    # Use Pandas to read and concatenate the CSV files into a single DataFrame object, merge them to the right, matchng the index column sub and ses
    # read csv as csv /t delimited
    dataframe = pd.read_csv(all_files[0], sep='\t')
    for file in all_files[1:]:
        #dont merge duplicates, keep the first onne
        dataframe = dataframe.merge(pd.read_csv(file, sep='\t'), on=['sub', 'ses', 'pipeline'], how='right')
        #if there is a column name with the same name but a _x or _y, only keep the first one, and erase the _x or _y
        dataframe = dataframe.loc[:,~dataframe.columns.duplicated()]
        dataframe.columns = dataframe.columns.str.replace('_x', '')
        dataframe.columns = dataframe.columns.str.replace('_y', '')
    # Save the merged DataFrame to a new CSV file one level above the folder
    # first delete the old all_measures.csv if it exists
    if os.path.exists(os.path.join(os.path.dirname(folder_path), 'all_measures.csv')):
        os.remove(os.path.join(os.path.dirname(folder_path), 'all_measures.csv'))
    # save the new all_measures.csv
    dataframe.to_csv(os.path.join(os.path.dirname(folder_path), 'all_measures.csv'), sep='\t', index=False)

    #delete all duplicate rows 
    dataframe.drop_duplicates(subset=['sub', 'ses', 'pipeline'], keep='first', inplace=True)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 merge_csv.py <folder_path>")
        sys.exit(1)
    
    measures_folder = sys.argv[1]
    
    # Ensure the provided folder exists
    if not os.path.exists(measures_folder) or not os.path.isdir(measures_folder):
        print(f"Error: The folder '{measures_folder}' does not exist or is not a directory.")
        sys.exit(1)

    merge_csv_files(measures_folder)
