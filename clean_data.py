import pandas as pd

target_cols = [
    'id', 'loan_amnt', 'funded_amnt', 'term', 'int_rate', 'installment', 'grade', 
    'sub_grade', 'emp_title', 'emp_length', 'home_ownership', 'annual_inc', 
    'verification_status', 'issue_d', 'loan_status', 'purpose', 'title', 
    'zip_code', 'addr_state', 'dti', 'total_pymnt'
]

print("Extracting matching columns... this may take a moment for a large file.")

# This reads the large file and extracts only our target columns
df = pd.read_csv('C:/Users/Public/LendingClub_LoanData.csv', usecols=target_cols, low_memory=False)

# This saves it into a clean file
df.to_csv('C:/Users/Public/LendingClub_Clean.csv', index=False)

print("Done! Clean file successfully created at C:/Users/Public/LendingClub_Clean.csv")
