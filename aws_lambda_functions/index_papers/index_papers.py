import boto3
import os
# parse pdf with PyPDF2
import PyPDF2
#from haystack.utils import convert_files_to_docs
from haystack.nodes import PreProcessor, EmbeddingRetriever
from haystack.document_stores import FAISSDocumentStore
from haystack.schema import Document

def pdf_to_text_with_pypdf2(pdf_folder_path):
    # It was not possible to use out of the boc the convert_files_to_docs function
    # somewhere deep in the haystack code, it uses semlock that is not suported by AWS Lambda

    print(f"pdf_to_text_with_pypdf2 {pdf_folder_path}")

    all_docs= []
    for file in os.listdir(pdf_folder_path):
        print(f"file in pdf_folder_path: {file}")
        f = pdf_folder_path + file
        # create a pdf file object
        pdfFileObj = open(f, 'rb')
        # create a pdf reader object
        reader = PyPDF2.PdfReader(pdfFileObj)

        text = ''
        # iterate over the pages, read the text, clean and add to the final text block
        for p in reader.pages:
            t = p.extract_text()
            t = t.encode('ascii', 'ignore').decode('utf-8')
            t = t.replace("\n", " ").replace("\x0c", " ")
            text += t

        # create Document object
        doc = {"content": text, "content_type": "text", "meta": {'name': f.split('/')[-1]}, "id":f.split('/')[-1]}
        doc = Document.from_dict(doc)
        all_docs.append(doc)

    return all_docs



def download_from_s3(bucket_name, prefix, tmp_folder):
    # simple function to get data from bucket and load it in tmp folder inside the lambda

    print(f"download_from_s3: {bucket_name} , {prefix} , {tmp_folder}")
    # download files from s3 to tmp folder
    s3 = boto3.client('s3')
    temp_files = []
    response = s3.list_objects_v2(
        Bucket=bucket_name,
        Prefix=prefix
    )


    print(f"response: {response}")

    if 'Contents' in response:
        s3_files = []
        for obj in response['Contents']:
            if obj["Size"] > 0:
                s3_files.append(obj['Key'])

        # Save all files to a temporary folder
        for file in s3_files:
            print(f"file in s3_files: {file}")
            f = file.split('/')[-1]
            s3.download_file(bucket_name, file, tmp_folder + f)
            temp_files.append(tmp_folder + f)

    return temp_files

def handler(event, context):
    # main method to be called by lambda to index papers and store them in FAISS DB
    s3 = boto3.client('s3')

    BUCKET_NAME = os.environ['BUCKET_NAME']
    API_KEY = os.environ['API_KEY']

    tmp_folder_faiss = '/tmp/faiss/'
    tmp_folder_input = '/tmp/input/'

    faiss_files = []
    pdf_files = []

    os.makedirs(tmp_folder_faiss, exist_ok=True)
    os.makedirs(tmp_folder_input, exist_ok=True)
    db_exists = False

    #################################################
    # Create the database
    #################################################

    # if there are files in the bucket, then download them to the temp folder
    # faiss db needs 3 files to exist, faiss_document_store_index.faiss, faiss_document_store_config.json, faiss_document_store.db
    faiss_files = download_from_s3(BUCKET_NAME, "faiss", tmp_folder_faiss)

    # if there are no db files, then create a new db
    if len(faiss_files) == 3:
        print("loading db")
        document_store = FAISSDocumentStore(faiss_index_path=f"{tmp_folder_faiss}faiss_document_store_index.faiss", faiss_config_path=f"{tmp_folder_faiss}faiss_document_store_config.json")
        db_exists = True


    if not db_exists:
        print("creating new db")
        # IMPORTANT: sqlite:////tmp/faiss/faiss_document_store.db has 4!!! slashes after sqlite
        document_store = FAISSDocumentStore(embedding_dim=1536, sql_url=f"sqlite:///{tmp_folder_faiss}faiss_document_store.db")
    
    # to prevent sql alchemy error - https://github.com/deepset-ai/haystack/issues/758  - did not help - trying out basic pzthon3 image
    document_store.use_windowed_query=False

    #################################################
    # Indexing documents to the database
    #################################################

    # download all the input files from the bucket to temp folder in lambda
    pdf_files = download_from_s3(BUCKET_NAME, "input", tmp_folder_input)
    print(f"pdf_files: {pdf_files}")

    if len(pdf_files) > 0:
        # OpenAI EmbeddingRetriever
        retriever = EmbeddingRetriever(
            document_store=document_store,
            batch_size=8,
            embedding_model="text-embedding-ada-002",
            api_key=API_KEY,
            max_seq_len=1536
        )
        print("retriever created")

        # PreProcessor
        # papers are split into documents of 7 sentences each
        preprocessor = PreProcessor(
            clean_whitespace=True,
            clean_header_footer=True,
            clean_empty_lines=True,
            split_by="sentence",
            split_length=7,
            split_overlap=1,
            split_respect_sentence_boundary=False,
        )
        print("preprocessor created")

        # convert pdf files to docs, then process them, then write them to the db
        #all_docs = convert_files_to_docs(dir_path=tmp_folder_data)  # the out of the box funstion that can not be used due to the semlock
        # pdf to text workaround for lambda
        all_docs = pdf_to_text_with_pypdf2(tmp_folder_input)
        print("all_docs converted from pdf to Document")

        # process the docs with the preprocessor (split in blocks, clean, etc)
        docs = preprocessor.process(all_docs)
        print("docs processed")

        # write the docs to the db
        document_store.write_documents(docs)
        print("docs written to db")

        # update the embeddings in the db (to enable semantic search)
        document_store.update_embeddings(retriever)
        print("docs written to db")


    # save the db -> faiss_document_store.db, faiss_document_store_index.faiss, faiss_document_store_config.json
    document_store.save(index_path=f"{tmp_folder_faiss}faiss_document_store_index.faiss", config_path=f"{tmp_folder_faiss}faiss_document_store_config.json")
    print("db saved")


    #################################################
    # Clean up
    #################################################

    # read files in tmp_folder_faiss folder and upload them to s3 /faiss folder
    for file in os.listdir(tmp_folder_faiss):
        print(f"uploading {file}")
        s3.upload_file(tmp_folder_faiss + file, BUCKET_NAME, 'faiss/' + file.split('/')[-1])
    
    print("faiss files uploaded")

    for file in pdf_files:
        # move processed files from input folder to processed folder in s3 bucket
        source_path = f'input/{file.split("/")[-1]}'
        destination_path = f'processed/{file.split("/")[-1]}'
        
        # Copy the object to the new location
        s3.copy_object(
            Bucket=BUCKET_NAME,
            CopySource={'Bucket': BUCKET_NAME, 'Key': source_path},
            Key=destination_path
        )
    # delete processed files from data folder in s3 bucket
    for file in pdf_files:
        print(f"deleting {file} from s3")
        s3.delete_object(Bucket=BUCKET_NAME, Key='input/' + file.split('/')[-1])

    # list all files in tmp_folder_faiss and delete them
    for file in os.listdir(tmp_folder_faiss):
        print(f"deleting {file} from tmp_folder_faiss")
        os.remove(tmp_folder_faiss + file)

    # list all files in tmp_folder_input and delete them
    for file in os.listdir(tmp_folder_input):
        print(f"deleting {file} from tmp_folder_input")
        os.remove(tmp_folder_input + file)


if __name__ == "__main__":
    pass


    



    