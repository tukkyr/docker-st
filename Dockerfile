FROM alpine:3 AS base-stage 

RUN apk add --no-cache bash tzdata curl wget vim git \
 && cp /usr/share/zoneinfo/Asia/Tokyo /etc/localtime \
 && wget https://raw.githubusercontent.com/git/git/master/contrib/completion/git-prompt.sh -O ${HOME}/.git-prompt.sh \
 && mkdir -p ${HOME}/.vim/autoload && wget https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim -O ${HOME}/.vim/autoload/plug.vim \
 && echo . ${HOME}/.git-prompt.sh >> ${HOME}/.bashrc \
 && echo "PS1='\[\e[36m\]\h\[\e[m\] \[\e[32m\]\W\[\e[m\] <\t> \$(__git_ps1 \"( %s ) \")\n\$'" >> ${HOME}/.bashrc \
 && apk del tzdata

RUN [ -z ${http_proxy} ] || echo export http_proxy=${http_proxy} >> ${HOME}/.bashrc

RUN echo -e "set nocompatible\n\
filetype off\n\n\
call plug#begin('~/.vim/plugged')\n\n\
Plug 'VundleVim/Vundle.vim'\n\n\
call plug#end()\n\
filetype plugin indent on\n\
syntax enable \n\n\
set st=4 ts=4 sw=4" | tee  ${HOME}/.vimrc

CMD ["sh", "-c", "while sleep 3600; do :; done"]

FROM base-stage AS python3-dev

WORKDIR /app

RUN apk add --no-cache python3 \
 && python3 -m venv .venv \
 && . .venv/bin/activate \
 && pip install -U pip setuptools \
 && pip install python-language-server flake8 \
 && echo . .venv/bin/activate >> ${HOME}/.bashrc

CMD ["bash"]
