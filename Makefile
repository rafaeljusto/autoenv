NAME        = autoenv
VERSION     = v$(shell git describe --always)

AUTHOR_EMAIL = rafaeljusto@users.noreply.github.com
AUTHOR_NAME  = 'Rafael Justo'

.PHONY: default install-yq chart-update git-prep git-push

default: git-push

install-yq:
	sudo add-apt-repository ppa:rmescandon/yq -y
	sudo apt update
	sudo apt install yq -y

chart-update: install-yq
	yq eval -i '.image.tag = "$(VERSION)"' helm/values.yaml

git-prep:
	git config --global user.email "$(AUTHOR_EMAIL)"
	git config --global user.name "$(AUTHOR_NAME)"

git-push: chart-update git-prep
	git commit -am "[ci skip] Updated helm chart to $(VERSION)"
	git push