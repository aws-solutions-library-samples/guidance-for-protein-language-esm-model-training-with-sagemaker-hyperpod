FROM nvcr.io/nvidia/pytorch:25.02-py3

COPY train.py /workspace

COPY 0.download_data.py /workspace

COPY 1.tokenize_uniref_csv.py /workspace

COPY requirements.txt /workspace

RUN pip install -r requirements.txt