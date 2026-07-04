Cria a branch:
  git switch -c nova_branch
  ou
  git branch nova_branch
  git switch nova_branch

Renomeia branch
 git branch -m master main

Quando terminar volta para main: 
  git switch main
Mescla:
  git merge nova_branch
Apaga a branch:
  git branch -d nova_branch
Apaga do github:
  git push origin --delete feature/dashboard-web

Restaura para versao antes do commit
  git restore main.c

Releases:
  git tag -a v1.0.0 -m "Primeira versão pública"

  git tag nova_tag antiga_tag       # cria a nova no mesmo commit
  git tag -d antiga_tag             # apaga a antiga localmente
  git push origin nova_tag          # envia a nova
  git push origin :antiga_tag       # apaga a antiga no remoto

  git push origin v1.0.0
  
  No GitHub:
    Vá em Releases
    Create a release
    Escolha a tag v1.0.0
    Escreva as notas
    Publique
