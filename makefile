TAG = sheldonh/etcd-toucher
MIRROR = 172.17.8.1:5000

release: mirrortag
	docker push ${MIRROR}/${TAG}

mirrortag: build
	docker tag ${TAG} ${MIRROR}/${TAG}

build:
	docker build -t ${TAG} .

.PHONY: build mirrortag release
