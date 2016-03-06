<?php

class StatoSistemaView extends BaseView {

	public function __construct($model) {

		parent::__construct($model);
		Assets::get()->addJs('/js/rainbow.js');
		Assets::get()->addJs('/js/statosistema.js');
	}

	public function render() {

		$tpl = Template::get()->loadTemplate('statosistema.tpl');

		return $tpl->render([
			'programmi' => $this->model->list,
			'antigelo' => $this->model->antigelo,
			'temperature' => $this->model->temperature,
			'rif_temp_attuale' => $this->model->rif_temp_attuale

		]);
	}

}