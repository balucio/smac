<?php

class ProgramDataRawView extends BaseView {

	public function render() {
		return json_encode((object)[
			'id_programma' => $this->model->id,
			'nome_programma' => $this->model->nome,
			'descrizione_programma' => $this->model->descrizione,
			'temperatura_antigelo' => $this->model->antigelo,
			'id_sensore_riferimento' => $this->model->id_sensore_rif,
			'temperature_riferimento' => $this->model->temperature
		]);
	}
}