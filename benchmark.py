import csv
import time

csv_path = "./Examples/large.csv"

csv_file = open(csv_path, "r", encoding="utf-8")

init_start = time.time()
csvReader = csv.DictReader(csv_file)
init_end = time.time()

parse_start = time.time()

counter = 0
for row in csvReader:
    counter += 1
    id = row["OBJECTID"]
parse_end = time.time()

print(f"Initialization time: {init_end - init_start:.4f} seconds")
print(f"Parsing time: {parse_end - parse_start:.4f} seconds")
print(f"Total rows parsed: {counter}")
print(f"Average time per row: {(parse_end - parse_start) / counter:.4f} seconds")
print(f"Total time: {parse_end - init_start:.4f} seconds")
print(f"Total time (without init): {parse_end - parse_start:.4f} seconds")
print(f"Total time (without init and parse): {parse_end - init_start:.4f} seconds")
csv_file.close()
