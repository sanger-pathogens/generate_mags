#!/usr/bin/env python3

import argparse
import hashlib
import logging
import os
import requests
import shutil
from pathlib import Path

def setup_logging(verbose=True):
    level = logging.INFO if verbose else logging.ERROR
    logging.basicConfig(format='%(levelname)s: %(message)s', level=level)

def download_file(url, dest_path):
    with requests.get(url, stream=True) as response:
        response.raise_for_status()
        with open(dest_path, 'wb') as f:
            shutil.copyfileobj(response.raw, f)

def md5sum(file_path):
    hash_md5 = hashlib.md5()
    with open(file_path, 'rb') as f:
        for chunk in iter(lambda: f.read(8192), b''):
            hash_md5.update(chunk)
    return hash_md5.hexdigest()

def main(output_dir, nextflow=False):
    setup_logging(verbose=not nextflow)

    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    version = args.version
    if not version:
        version_url = "https://ftp.ncbi.nlm.nih.gov/sra/dbs/human_filter/current/version.txt"
        try:
            version = requests.get(version_url).text.strip()
            if not version:
                logging.error("Failed to retrieve version.")
                return 1
        except Exception as e:
            logging.error(f"Error retrieving version: {e}")
            return 1

    filename = f"human_filter.db.{version}"
    filepath = output_dir / filename

    md5_url = f"https://ftp.ncbi.nlm.nih.gov/sra/dbs/human_filter/{filename}.md5"
    try:
        expected_md5 = requests.get(md5_url).text.strip()
        if not expected_md5:
            logging.error("Failed to retrieve MD5 checksum.")
            return 2
    except Exception as e:
        logging.error(f"Error retrieving MD5 checksum: {e}")
        return 2

    if filepath.exists():
        actual_md5 = md5sum(filepath)
        if actual_md5 == expected_md5:
            logging.info("Database is already up to date.")
            if nextflow:
                print(filepath.resolve())
            return 0
        else:
            logging.warning("File exists but checksum does not match. Re-downloading.")

    download_url = f"https://ftp.ncbi.nlm.nih.gov/sra/dbs/human_filter/{filename}"
    logging.info(f"Downloading {filename}...")
    try:
        download_file(download_url, filepath)
    except Exception as e:
        logging.error(f"Download failed: {e}")
        return 3

    actual_md5 = md5sum(filepath)
    if actual_md5 != expected_md5:
        logging.error(f"Checksum mismatch. Got {actual_md5}, expected {expected_md5}")
        filepath.unlink(missing_ok=True)
        return 3

    logging.info(f"Successfully downloaded {filename}.")
    if nextflow:
        print(filepath.resolve())
    return 0

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Download the latest human_filter.db file.")
    parser.add_argument("output_dir", help="Directory to save the database file")
    parser.add_argument("--version", help="Specific version of the database to download")
    parser.add_argument("--nextflow", action="store_true", help="Only print the path to the downloaded file for Nextflow integration")
    args = parser.parse_args()
    raise SystemExit(main(args.output_dir, nextflow=args.nextflow))
