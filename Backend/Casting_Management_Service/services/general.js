import { Audition } from "../models/audition.js";
import { Sentence } from "../models/sentence.js"

export const getAudition = async (req, res, next) => {
    try {
        const audition_id = req.params.audition_id;
        let audition = await Audition.findById(audition_id);

        if (!audition){
            return res.status(404).json({message: 'audition not found'});
        }

        const script = await Sentence.findByAuditionId(audition_id);
        audition = {...audition, script };
        return res.status(200).json({audition});
    } catch (error) {
        console.log("Error getting audition");
        console.error(error);
        next(error);
    }
};