<?php

class StatoSistemaView extends BaseView {

	public function __construct($model) {

		parent::__construct($model);
		$asset = Assets::get();
		$asset->addJs('/js/rainbow.js');
		$asset->addJs('/js/statosistema.js');

		$asset->addInternalCss('
			.btn-group.pull-right {margin-top: -0.2em;}
			.status { text-shadow: 1px 1px 1px black; }
			.status.on { color: red; }
			.status.off { color: lightseagreen; }
			.status.undefined { color : red; }
		');
	}

	public function render() {

		$tpl = Template::get()->loadTemplate('statosistema.tpl');

		return $tpl->render([
			'programmi' => $this->model->list,
			'antigelo' => $this->model->antigelo,
			'temperature' => $this->model->temperature,
			'rif_temp_attuale' => $this->model->rif_temp_attuale,
			'sensore_rif' => $this->model->nome_sensore_rif

		]);
	}

}