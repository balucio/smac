<?php

class StatisticheView extends MainView {

	const
		TPL = 'statistiche.tpl'
	;

	public function __construct($model) {

		parent::__construct($model, self::TPL);

		Assets::get()->addJs([]);
	}

	public function render() {

		return parent::render();
	}
}