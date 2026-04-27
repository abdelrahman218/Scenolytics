import dotenv from "dotenv";

dotenv.config();

const FRONTEND_DASHBOARD_LINK = process.env.FRONTEND_DASHBOARD_LINK || "http://localhost:5173";

export const generateEmailTemplate = (title, message) => {
  return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <style>
        body { font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif; background-color: #f4f4f5; margin: 0; padding: 0; }
        .container { max-width: 600px; margin: 40px auto; background-color: #ffffff; border-radius: 8px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.05); }
        .header { background-color: #111827; color: #ffffff; padding: 24px; text-align: center; }
        .header h1 { margin: 0; font-size: 24px; font-weight: 600; letter-spacing: 1px; }
        .content { padding: 32px; color: #282e36ff; line-height: 1.6; font-size: 16px; }
        .title { font-size: 20px; font-weight: 600; color: #111827; margin-top: 0; margin-bottom: 16px; }
        .button-container { text-align: center; margin-top: 32px; margin-bottom: 16px; }
        .button-container a { color: #ffffff }   
        .button { background-color: #3b82f6; color: #ffffff; padding: 12px 24px; text-decoration: none; border-radius: 6px; font-weight: 500; display: inline-block; }
        .footer { background-color: #f9fafb; padding: 24px; text-align: center; color: #6b7280; font-size: 14px; border-top: 1px solid #e5e7eb; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>SCENOLYTICS</h1>
        </div>
        <div class="content">
          <h2 class="title">${title}</h2>
          <p>${message.replace(/\n/g, '<br>')}</p>
          
          <div class="button-container">
            <a href="${FRONTEND_DASHBOARD_LINK}/dashboard" class="button">Go to Dashboard</a>
          </div>
        </div>
        <div class="footer">
          <p>You are receiving this email because of your notification preferences on Scenolytics.</p>
          <p>&copy; ${new Date().getFullYear()} Scenolytics. All rights reserved.</p>
        </div>
      </div>
    </body>
    </html>
  `;
};
