<?php

class StatoSensoriView extends BaseView {

	public function __construct($model) {

		parent::__construct($model);
		Assets::get()->addJs('/js/situazione.js');
	}

	public function render() {

		$tpl = Template::get()->loadTemplate('statosensori.tpl');

		return $tpl->render([
			'sensore' => $this->model->get('data'),
			'sensori' => $this->model->get('list')
		]);
	}

}