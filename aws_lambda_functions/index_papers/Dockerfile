# Following gude for non-aws base image https://docs.aws.amazon.com/lambda/latest/dg/python-image.html#python-image-clients
# official aws lambda image for python 3.10 has older sqlite3 version resulting in sqlalchemy.exc.OperationalError -> https://github.com/deepset-ai/haystack/issues/974

# Define custom function directory
ARG LAMBDA_TASK_ROOT="/function"

# using base python:3.10 image
FROM python:3.10

USER root

# Include global arg in this stage of the build
ARG LAMBDA_TASK_ROOT

# Create /functions folder
RUN mkdir -p ${LAMBDA_TASK_ROOT}

# Install the function's dependencies
COPY requirements.txt  .
RUN pip install -r requirements.txt --target "${LAMBDA_TASK_ROOT}"

# Copy function code
COPY index_papers.py ${LAMBDA_TASK_ROOT}

# Set working directory to function root directory
WORKDIR ${LAMBDA_TASK_ROOT}

# Set runtime interface client as default command for the container runtime
ENTRYPOINT [ "/usr/local/bin/python", "-m", "awslambdaric" ]
# Pass the name of the function handler as an argument to the runtime
CMD [ "index_papers.handler" ]