import express from "express";
import { logIn, signUp, validateUserExists } from "../services/auth.js";
import { signUpRequiredFieldsValidator, logInRequiredFieldsValidator, checkUserExistsValidator } from "../validators/auth.js";

const router = express.Router();

// Endpoints
router.post("/signup", signUpRequiredFieldsValidator, checkUserExistsValidator, signUp);
router.post("/login", logInRequiredFieldsValidator, logIn);
router.get("/validate/:user_id", validateUserExists);

export default router;