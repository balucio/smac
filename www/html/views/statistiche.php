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

		$this->addData([
			'commutazioni' => $this->renderSwitching(),
		]);

		return parent::render();
	}


	protected function renderSwitching() {

		$sw = $this->model->getCommutazioni();

		$stati = [
			'acceso' => 0,
			'spento' => 0,
			'indeterminato' => 0
		];

		foreach ($sw as $v) {
			if ($v['stato'] === true)
				$stati['acceso'] += $v['durata'];
			else if ($v['stato'] === false)
				$stati['spento'] += $v['durata'];
			else
				$stati['indeterminato'] += $v['durata'];
		}

		return [
			'elenco' => $sw,
			'totale' => $stati
 		];


	}
}