   <?php

class ImpostazioniController extends GenericController {

    private
        $models
    ;

    public
        $programma,
        $dettaglio
    ;

    public function __construct($model) {

        $this->model = $model;

        $this->programma = new ProgrammaController($this->model->programma);
        $this->dettaglio = new ProgrammaController($this->model->programma);

        $this->programma->elenco();
        $this->dettaglio->dati();

    }
}