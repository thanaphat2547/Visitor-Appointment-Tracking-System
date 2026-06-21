const config = require('../../configuration/connection');
const db = require("../../libraty/pgConnection");
const moment = require('moment');
const express = require('express');

exports.postcheckbeacon = async (req,res) => {

    try{
    
    const {bc_uuid} = req.body;

    const script = `SELECT bc_name,bc_uuid,bc_id FROM tb_beacon WHERE bc_uuid = $1 AND bc_flag = '1'`;
    
    const result = await db.get(null, script, config, [bc_uuid]);

    if(result.data && result.data.length > 0){
        res.status(200).json({
            found: true,
            beacon: result.data[0]
        });
    }else{
        res.status(200).json({
            found: false
        });
    }

}catch(err){
    console.error("Error in checkBeacon:", err);
    res.status(500).json({ message: "Internal Server Error" });
}
}