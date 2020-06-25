<?php

session_start();

#$conn = mysqli_connect(
    # 'locahost',
    # 'root', 
    # '',
    # 'uasd_virtual');

//if (isset($conn)){echo 'Estas Conectado a la base de datos' ;}

class Conexion{
    protected static function conectar(){
        $conexion = new mysqli('localhost','root', '', 'aulas_virtuales');
        return $conexion;
    }

    public static function consultar($sql){
        
        if(self::conectar()->connect_errno){
            die('Hubo un error!');
        }else{
            $resultados = self::conectar()->query($sql);
            if($resultados->num_rows){
                return $resultados;
            }
        }
    }

    protected static $id = NULL;
   


    public static function ingresar($materia, $coordinador, $docente, $materia_completa, $materia_incompleta){
        if(self::conectar()->connect_errno){
            die('Hubo un error en la conexion!');           
        }else{
            $conexion = self::conectar();
            $sql = $conexion->prepare("INSERT INTO asignaturas(id, materia, coordinador, docente, materia_completa, materia_incompleta) VALUES(?,?,?,?,?,?)");
            $sql->bind_param('ssssss', self::$id, $materia, $coordinador, $docente, $materia_completa, $materia_incompleta);
            $sql->execute();
        }
    }

}


$resultados = Conexion::consultar('SELECT * from asignaturas');
#print_r($resultados->fetch_assoc());


?>