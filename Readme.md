Build the container
  `docker build  --network=host  -t tomcat . -f dockerfile`
  
Run the container as 
  `docker run -it --rm --name tomcat -e MYSQL_DATABASE=hice -e MYSQL_ROOT_PASSWORD=mysql188$ -e 'MYSQL_INITDB_SKIP_TZINFO=true' -p 3306:3306 tomcat`
