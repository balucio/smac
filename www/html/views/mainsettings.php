<?php

class MainSettingsView extends MainView {

	const
		TPL = 'systemsettings.tpl'
	;

	public function __construct($model) {

		parent::__construct($model, self::TPL);

		// Assets::get()->addJs([]);
	}

	public function render() {

		$this->addData([
			'sensori' => $this->model->sensori,
			'antigelo' => $this->model->antigelo,
			'manuale' => $this->model->manuale,
		]);

		return parent::render();
	}
}