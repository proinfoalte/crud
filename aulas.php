<?php  include("bd1.php"); ?>


<?php  include("include1/header.php"); ?>


<div class="container p-4">

    <div class="row">

    <div class="col-md-4">
<!--inicio de linea de mensaje de alerta-->
    <?php if (isset($_SESSION['message'])) { ?>
        <div class="alert alert-<?= $_SESSION['message_type'];?> alert-dismissible fade show" role="alert">
            <?= $_SESSION['message'] ?>
            <button type="button" class="close" data-dismiss="alert" aria-label="Close">
    <span aria-hidden="true">&times;</span>
  </button>
        </div>
    <?php session_unset(); } ?>
    <!--final de linea de mensaje de alerta-->

    <div class="card card-body">
    <form action="guardar1.php" method="POST">
    <div class="form-group">
    <input type="text" name="MATERIA" class="form-control"
     placeholder="MATERIA VIRTUAL" autofocus>
    </div>
    <div class="form-group">
    <input type="text" name="COORDINADOR" class="form-control"
     placeholder="COORDINADOR DE LA ASIGNATURA" autofocus>
    </div>
    <div class="form-group">
    <input type="text" name="DOCENTE" class="form-control"
     placeholder="DOCENTE DE LA ASIGNATURA VIRTUAL" autofocus>
    </div>
    <div class="form-group">
    <input type="text" name="MATERIA_COMPLETA" class="form-control"
     placeholder="MATERIA COMPLETA" autofocus>
    </div>
    <div class="form-group">
    <input type="text" name="MATERIA_INCOMPLETA" class="form-control"
     placeholder="MATERIA INCOMPLETA" autofocus>
    </div>
    <input type="submit" class="btn btn-success btn-block" name="Guardar" value="Guardar">
    </form>

    </div>


    </div>
    <div class="col-md-8">
    <table class="table table-border">
    <thead>
    <tr>
    <th>MATERIA</th>
    <th>COORDINADOR</th>
    <th>DOCENTE</th>
    <th>MATERIA COMPLETA</th>
    <th>MATERIA INCOMPLETA</th>
    <th>EDITAR</th>
    </tr>
    </thead>
    <tbody>
    <?php $resultados = Conexion::consultar("SELECT * FROM asignaturas")?>
    <?php if(!empty($resultados)) {?>
    <?php while($row = $resultados->fetch_assoc()) {?>
        <tr>
        <td><?php echo $row['materia'] ?> </td>
        <td><?php echo $row['coordinador'] ?> </td>
        <td><?php echo $row['docente'] ?> </td>
        <td><?php echo $row['materia_completa'] ?> </td>
        <td><?php echo $row['materia_incompleta'] ?> </td>
        <td>
        <a href="editar1.php?id=<?= $row['id'] ?>" class="btn btn-success">
        <i class="fas fa-marker"></i>
        </a>
        <a href="eliminar1.php?id=<?= $row['id'] ?>"class="btn btn-danger" >
        <i class="fas fa-trash-alt"></i>
        </a>
        </td>
        </tr>

        <?php } ?>
    <?php } else{?>
        
        <tr>
            <td> - </td>
            <td> - </td>
            <td> - </td>
            <td> - </td>
            <td> - </td>
            <td> - </td>
        </tr>
    <?php }?>

    </tbody>
    </table>
    
    </div>
    </div>
    </div>
<?php  include("include1/footer.php"); ?>