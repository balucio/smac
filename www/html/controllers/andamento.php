<?php

class AndamentoController extends GenericController {

    const H_SECONDS = 3600;
    const MAX_RANGE = 8035200; // 3 months

    protected
        $sensor = null,
        $interval = null,
        $date_start = null,
        $isInit = false
    ;


    public function __construct($model) {

        $this->model = $model;

        $this->sensor = Request::Attr('sensor', null);
        $this->sensor <= 0 && $this->sensor = null;

        $this->interval = Request::Attr('interval', self::H_SECONDS);
        $this->interval <= 0 && $this->interval = self::H_SECONDS;

        $this->date_start = Request::Attr('date_start', null);
    }

    public function temperatura() {
        return $this->setReportParams(AndamentoModel::TEMPERATURA, $this->sensor, $this->date_start);
    }

    public function umidita() {
        return $this->setReportParams(AndamentoModel::UMIDITA, $this->sensor);
    }

    public function isInitialized() { return $this->isInit; }

    private function setReportParams($type, $sensor = null, $start_epoch = null, $end_epoch = null) {

        $cUtc = Db::UTC();

        $start_epoch = (
            ( is_null($start_epoch)
                || ( Db::UTC($start_epoch) - $cUtc ) > Self::MAX_RANGE
            )) ? ( $cUtc - $this->interval)
              : Db::UTC($start_epoch)
        ;

        $end_epoch = Db::UTC($end_epoch);
        $end_epoch = $end_epoch > $start_epoch ? $end_epoch : $cUtc;

        if ($end_epoch - $start_epoch > Self::MAX_RANGE)
            $end_epoch = $start_epoch + Self::MAX_RANGE;

        $this->model->setPhysicalType($type)
            ->setSensorId($sensor)
            ->setStartDate( Db::Timestamp($start_epoch) )
            ->setEndDate( Db::Timestamp($end_epoch) );

        $this->isInit = true;

        return $this;
    }



}