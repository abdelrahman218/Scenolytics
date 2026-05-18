import express from "express";
import { getAudition } from "../services/general.js";

const router = express.Router();

//Get Audition
router.get("/auditions/:audition_id", getAudition);

export default router;
