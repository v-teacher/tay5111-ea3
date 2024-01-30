# Instrucciones Evaluación Parcial EA3: Almacenamiento en la nube 35%


Cada alumno, deberá desplegar la siguiente infraestructura el AWS.



* Cree un "Security Group" que permita conexiones al puerto tcp/80 (http), tcp/443 (https) y tcp/22 (ssh).
* Cree un bucket S3, copie el siguiente archivo “.php”:


### index.php
```
<html xmlns="http://www.w3.org/1999/xhtml" >
<head>
<title>My Website Home Page</title>
</head>
<body>
<h1>Welcome to my website</h1>
<p>Now hosted on: <?php echo gethostname(); ?></p>
<p><?php
$my_current_ip=exec("ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'");
echo $my_current_ip; ?></p>
</body>
</html>
```


* Lance un volumen EFS, el cual se utilizara posteriormente para almecenar el archivo index.php, ubicado inicialmente en el bucket S3.


*Lanze 3 Instancias Virtuales en EC2, cada una en una AZ distinta (availability zone). 
*Para cada una de estas instancias, asocie la llave de usuario (Key user) "vockey" y el "Security Group" configurado inicialmente.


* Al momento de lanzar la instancia, instale el servicio webserver (apache), php, monte el recursos EFS en el path "/var/www/html" y copie desde el bucket S3, el archivo “index.php” hacie el path /var/www/html (EFS). en cada instancia EC2. (Puedes usar “EC2 user data” para realizar esto).

```
#!/bin/bash
yum install -y httpd php wget
systemctl start httpd
systemctl enable httpd

```


* Cree un Balanceador de Carga (ALB) en AWS adjuntando las 3 máquinas creadas antes como targets. Este ALB también debe aceptar conexiones en el puerto 80 desde cualquier dirección IP.
