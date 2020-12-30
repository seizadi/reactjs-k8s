.PHONY: docker
docker:
		docker build -t soheileizadi/reactjs-k8s:latest .
		docker push soheileizadi/reactjs-k8s:latest
