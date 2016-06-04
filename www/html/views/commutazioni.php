<?php

class CommutazioniView extends MainView {

	const
		TPL = 'lista-commutazioni.tpl'
	;

	public function __construct($model) {

		parent::__construct($model, self::TPL);
	}

	public function render() {

		$stati = [
			'acceso' => 0,
			'spento' => 0,
			'indeterminato' => 0
		];

		foreach ($this->model->result as $v) {

			if ($v === true)
				$stati['acceso'] += $v['durata'];
			else if ($v === false)
				$stati['spento'] += $v['durata'];
			else
				$stati['indeterminato'] += $v['durata'];
		}

		$commutazioni = [
			'elenco' => $this->model->result,
			'totale' => $stati
 		];

		$this->addData(['commutazioni' => $commutazioni]);

		return parent::render();
	}
}