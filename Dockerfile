FROM public.ecr.aws/lambda/nodejs:18
COPY . .
CMD [ "index.handler" ]