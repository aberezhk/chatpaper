import boto3
import os
import json
from haystack.pipelines import Pipeline
from haystack.nodes import EmbeddingRetriever, PromptNode
from haystack.document_stores import FAISSDocumentStore

def download_from_s3(bucket_name, prefix, tmp_folder):
    # simple method to download files from s3 to tmp folder
    # code duplicated wrom index_papers.py

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
    # lambda function to search papers in FAISS DB
    # function expects a POST request with a body containing a question in the format {"question": "what is the meaning of life?"}
    # IMPORTANT - In all responses the Access-Control-Allow-Origin header is set to allow CORS

    s3 = boto3.client('s3')

    BUCKET_NAME = os.environ['BUCKET_NAME']
    API_KEY = os.environ['API_KEY']

    # return error if request has no body
    if "body" not in event:
        return {
        "statusCode": 400, 
        'headers' : {
            'Access-Control-Allow-Origin' : '*'
        },
        "error": "No body provided"
    }


    # extract question from body
    b = json.loads(event["body"])

    # return error if question is not in body
    if "question" not in b:
        return {
        "statusCode": 400, 
        'headers' : {
            'Access-Control-Allow-Origin' : '*'
        },
        "error": "No question provided"
    }

    question = b["question"]


    #################################################
    # Load the database
    #################################################
    tmp_folder_faiss = '/tmp/faiss/'
    faiss_files = []

    os.makedirs(tmp_folder_faiss, exist_ok=True)

    # download db files from s3
    faiss_files = download_from_s3(BUCKET_NAME, "faiss", tmp_folder_faiss)

    if len(faiss_files) == 3:
        document_store = FAISSDocumentStore(faiss_index_path=f"{tmp_folder_faiss}faiss_document_store_index.faiss", faiss_config_path=f"{tmp_folder_faiss}faiss_document_store_config.json")
        print("loading db")
    # if no db files found return error
    else:
        print("no db files found")
        return
    
    # to prevent sql alchemy error - https://github.com/deepset-ai/haystack/issues/758 - did not actuallz solve the problem
    document_store.use_windowed_query=False

    #################################################
    # Search documents
    #################################################

    # initialize embedding retriever
    retriever = EmbeddingRetriever(
    document_store=document_store,
    batch_size=8,
    embedding_model="text-embedding-ada-002",
    api_key=API_KEY,
    max_seq_len=1536
    )
    print("retriever initialized")

    # retrieve 5 most relevant documents
    candidate_documents = retriever.retrieve(
        query=question,
        top_k=5
    )
    print(f"candidate_documents found: {len(candidate_documents)}")

    # initialize prompt node with OpenAI API model
    # https://prompthub.deepset.ai/?prompt=deepset%2Fquestion-answering-with-references
    prompt_node = PromptNode(model_name_or_path="gpt-3.5-turbo", api_key=API_KEY, default_prompt_template='question-answering-with-references')
    pipe = Pipeline()
    pipe.add_node(component=prompt_node, name="prompt_node", inputs=["Query"])

    # run pipeline
    output = pipe.run(query=question, documents=candidate_documents)

    print(f"pipe.run output received")

    result = {
        "question": question,
        "answer" : output["answers"][0].answer
    }

    papers = set()
    documents = []

    for i, d in enumerate(output["documents"]):
        papers.add(d.meta["name"])
        doc = {
            "id": f"Document {i +1}",
            "paper": d.meta["name"],
            "citation": d.content
        }
        documents.append(doc)

    result["papers"] = list(papers)
    result["documents"] = documents

    """
    response format:
    {
        "question": "What is the meaning of life?",
        "answer": "The meaning of life is 42.",
        papers: ["paper1", "paper2"],
        documents: [
            {
                "id": "Document 1",
                "paper": "paper1",
                "citation": "citation1"
            },
            {
                "id": "Document 2",
                "paper": "paper2",
                "citation": "citation2"
            }
        ]
    }
    """
    
    return {
        "statusCode": 200, 
        'headers' : {
            'Access-Control-Allow-Origin' : '*'
        },
        "body": json.dumps(result)
    }


if __name__ == "__main__":
    pass


    



    