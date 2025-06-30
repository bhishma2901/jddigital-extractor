# JD Digital Extractor

A Flutter app for batch image OCR and text/number extraction.

## Features
- Upload images or zip files
- Crop first image and apply crop to all
- OCR using EasyOCR and Google ML Kit
- Multiple extraction types (all text, only text, only numbers, 7+ digit numbers)
- Output as CSV, sorted by filename
- TXT file fixer for 7+ digit numbers
- Built with GitHub Actions

## How to Use
1. Upload images or a zip file containing images.
2. Crop the first image and apply the crop to all images.
3. Select extraction type (expandable options).
4. Extract and save output as CSV.
5. Use TXT fixer to extract 7+ digit numbers from a text file.

## Build APK
APK is built automatically on every push to `main` using GitHub Actions. Download from workflow artifacts.