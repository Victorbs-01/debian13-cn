1. setup pcs con nvidia grafica. 
2. entra a github.com , logue con user y pass
3. baja los archivos de este repo
4. corre el scrip1 para hacer mirror a tuna y bajar curl. 
5. baja tailscale loggin con github, corre tailscale
6. sudo tailscale up --exit-node=dev01 --accept-dns=true
7. usa el pc servidor para tener mejor internet
8. corre el scrip2 para instalar drivers y archivos. 

9. reinicia y valida 
nvidia-smi
docker run --rm hello-world
node -v && pnpm -v
htop
nvtop

10. ajusta resoluciones. 
11. 