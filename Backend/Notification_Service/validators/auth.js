import jwt from "jsonwebtoken";

const JWT_SECRET = process.env.JWT_SECRET;

function extractTokenFromHeader(req, res) {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
        return res.status(401).json({
            message: "Authorization header missing or malformed",
        });
    }
    const token = authHeader.split(" ")[1];
    return token;
};

export const validateJWTToken = (req, res, next) => {
    const token = extractTokenFromHeader(req, res);
    try {
        const decoded = jwt.verify(token, JWT_SECRET);
        req.user = decoded;
        next();
    } catch (error) {
        return res.status(401).json({
            message: "Invalid or expired token",
        });
    }
};

export const validateJWTTokenForSocketIo = (token) => {
    return jwt.verify(token, JWT_SECRET);
}