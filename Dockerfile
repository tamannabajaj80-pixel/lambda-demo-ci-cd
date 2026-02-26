FROM public.ecr.aws/lambda/nodejs18.x
COPY . .
CMD [ "index.handler" ]