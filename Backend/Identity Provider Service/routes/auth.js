import express from "express";
import { logIn, signUp } from "../services/auth.js";
import { signUpRequiredFieldsValidator, logInRequiredFieldsValidator, checkUserExistsValidator } from "../validators/auth.js";

const router = express.Router();

// Endpoints
router.post("/signup", signUpRequiredFieldsValidator, checkUserExistsValidator, signUp);
router.post("/login", logInRequiredFieldsValidator, logIn);

export default router;