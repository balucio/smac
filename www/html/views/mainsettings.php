<?php

class MainSettingsView extends MainView {

	const
		TPL = 'systemsettings.tpl'
	;

	public function __construct($model) {

		parent::__construct($model, self::TPL);
	}

	public function render() {

		$this->addData([
			'sensori' => $this->model->list,
			'antigelo' => $this->model->antifreezeTemp,
			'manuale' => $this->model->manualTemp,
			'santigelo' => $this->model->antifreezeSensor,
			'smanuale' => $this->model->manualSensor,
			'pin_rele' => $this->model->pinRele
		]);

		return parent::render();
	}
}