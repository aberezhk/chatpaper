# Define custom function directory
ARG LAMBDA_TASK_ROOT="/function"

# using python:3.10
# official deepset/haystack-cpu:latest image on the one hand does not support default_prompt_template, and on the other AnswerParser to use promptTemplate
FROM python:3.10

USER root

# Include global arg in this stage of the build
ARG LAMBDA_TASK_ROOT

# Copy function code
RUN mkdir -p ${LAMBDA_TASK_ROOT}
# Install the function's dependencies
COPY requirements.txt  .
RUN pip install -r requirements.txt --target "${LAMBDA_TASK_ROOT}"

COPY search_papers.py ${LAMBDA_TASK_ROOT}

# Set working directory to function root directory
WORKDIR ${LAMBDA_TASK_ROOT}

# Set runtime interface client as default command for the container runtime
ENTRYPOINT [ "/usr/local/bin/python", "-m", "awslambdaric" ]
# Pass the name of the function handler as an argument to the runtime
CMD [ "search_papers.handler" ]