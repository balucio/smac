<?php

class SensorStatusModel {

    const
        IN_MEDIA_SENSOR = 'inmedia',
        OTHER_SENSOR = 'altri'
    ;

    private
        $sensorStatus = null,
        $sList = null
    ;


    public function __construct() {

        $this->sensorStatus = new SensorDataModel();

    }

    public function initData() {

        // Imposto di default il sensore "Media" ed elenco i sensori
        $this->sensorStatus->setSensorId(null);
        $this->enumerate();
    }

    public function sensordata() { return $this->sensorStatus; }

    public function sensorlist($type) { return $this->sList->$type; }


    public function enumerate() {

        $query = "SELECT id_sensore, nome_sensore, incluso_in_media"
            . " FROM sensori"
           . " WHERE abilitato"
        . " ORDER BY incluso_in_media DESC, nome_sensore ASC";

        $this->sList = (object)[];
        $this->sList->inmedia = $this->sList->altri = [];

        foreach (Db::get()->getResultSet($query) as $sensor) {

            if ($sensor['incluso_in_media'])
                $this->sList->inmedia[] = $sensor;
            else
                $this->sList->altri[] = $sensor;

        }

        return $this;

    }

}