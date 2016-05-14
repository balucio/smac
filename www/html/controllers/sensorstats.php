<?php

class SensorStatsController extends BaseController {

	const

		// Soglia aggiornamento statistiche odierne
		THR_STATS_UPDATE = 3600,
		// Secondi in un ora
		DEF_INTERVAL = 3600,
		// Tre mesi
		MAX_INTERVAL = 8035200,
		// Numero massimo di punti da processare
		MAX_POINT_NUM = 300
	;

	public function __construct($model, $init = true) {

		parent::__construct($model, $init);
		$this->setDefaultAction('temperatura');

		$lu = isset($_SESSION['today_stats_last_update'])
			? $_SESSION['today_stats_last_update'] : 0;

		if (time() - $lu > self::THR_STATS_UPDATE
			&& method_exists($this->model, 'update_today_stats')
		) {
				$this->model->update_today_stats();
				$_SESSION['today_stats_last_update'] = time();
		}
	}

	public function temperatura() {

		$this->model->setPhysicalType(SensorStatsModel::TEMPERATURA);
	}

	public function umidita() {

		$this->model->setPhysicalType(SensorStatsModel::UMIDITA);
	}

	protected function initFromRequest() {

		$sid = Request::Attr('sensor', null);

		if (!is_null($sid)
			&& ($sid == '0' || Validate::IsPositiveInt($sid))
		) {
			$this->model->setSensorId($sid);
		}

		$points = Request::Attr('points_number', null);

		if (!is_null($points) 
			&& Validate::IsPositiveInt($points)
			&& $points <= self::MAX_POINT_NUM

		)
			$this->model->setNumberOfPoint($points);

		$int = Request::Attr('interval', null);
		$int = Validate::IsPositiveInt($int) ? $int : self::DEF_INTERVAL;
		$int = min($int, self::MAX_INTERVAL);

		$sd = Request::Attr('start_date', null);
		$ed = Request::Attr('end_date', null);

		$vsd = Validate::IsValidTimeStamp($sd);
		$ved = Validate::IsValidTimeStamp($ed);

		if ( $vsd && $ved ) {

			if ( $sd > $ed ) {
				$tmp = $sd;
				$sd = $ed;
				$ed = $tmp;
			} else if ( $sd == $ed ) {
				$sd = $ed - $int;
			}

			if ( $ed - $sd > self::MAX_INTERVAL )
				$sd = $ed - self::MAX_INTERVAL;

			$this->model->setStartDate( Db::TimestampWt( $sd ) );
			$this->model->setEndDate( Db::TimestampWt( $ed ) );

		} else if ( $vsd ) {

			$this->model->setStartDate( Db::TimestampWt( $sd ) );
			$this->model->setEndDate( Db::TimestampWt( $sd + $int ) );

		} else {

			$ed = $ved ? $ed : time();

			$this->model->setStartDate( Db::TimestampWt( $ed - $int ) );
			$this->model->setEndDate( Db::TimestampWt( $ed ) );
		}
	}
}