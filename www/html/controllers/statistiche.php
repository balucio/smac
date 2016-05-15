<?php

class StatisticheController extends BaseController {

	const
		// Soglia aggiornamento statistiche odierne
		THR_STATS_UPDATE = 3600
	;
	
	public function __construct($model) {

		parent::__construct($model, false);

		$lu = isset($_SESSION['today_stats_last_update'])
			? $_SESSION['today_stats_last_update'] : 0;

		if (time() - $lu > self::THR_STATS_UPDATE
			&& method_exists($this->model, 'update_today_stats')
		) {
				$this->model->update_today_stats();
				$_SESSION['today_stats_last_update'] = time();
		}

		$this->setDefaultAction('view');
	}

	public function view() {

	}
}