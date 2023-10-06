import pandas as pd
import os
import sys

def remove_duplicate_columns(df):
    # Return DataFrame without duplicate columns
    return df.loc[:, ~df.columns.duplicated()]

def merge_csv_files(folder_path):
    # List all files in the given folder
    print(f"Listing all CSV files in {folder_path}...")
    all_files = [os.path.join(folder_path, f) for f in os.listdir(folder_path) if f.endswith('.csv')]

    if not all_files:
        print("No CSV files found in the specified folder.")
        return

    # Segregate the files into long_ files and others
    long_files = [f for f in all_files if 'long_' in os.path.basename(f)]
    other_files = [f for f in all_files if 'long_' not in os.path.basename(f)]

    def merge_files(files):
        if not files:
            return pd.DataFrame()  # Return empty DataFrame if files list is empty
        df = pd.read_csv(files[0], sep='\t')
        for file in files[1:]:
            print(f"Merging {file}...")
            df = df.merge(pd.read_csv(file, sep='\t'), on=['sub', 'ses', 'pipeline'], how='right')
            df = df.loc[:, ~df.columns.duplicated()]
            df.columns = df.columns.str.replace('_x', '').str.replace('_y', '')
        return df

    
    long_df = merge_files(long_files)
    other_df = merge_files(other_files)

    # Remove duplicate columns from each DataFrame
    long_df = remove_duplicate_columns(long_df)
    other_df = remove_duplicate_columns(other_df)

    # Create a combined list of all unique columns
    # Create a combined list of all columns from both dataframes
    all_columns = long_df.columns.tolist() + [col for col in other_df.columns if col not in long_df.columns]

    # Reindex both dataframes to have the same columns
    long_df = long_df.reindex(columns=all_columns)
    other_df = other_df.reindex(columns=all_columns)

    # Concatenate the two DataFrames
    final_df = pd.concat([long_df, other_df], axis=0, ignore_index=True)

    # Save the merged DataFrame to a new CSV file one level above the folder
    output_file = os.path.join(os.path.dirname(folder_path), 'all_measures.csv')
    if os.path.exists(output_file):
        os.remove(output_file)
    final_df.to_csv(output_file, sep='\t', index=False)

    print("Merging process completed!")

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

