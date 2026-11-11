package com.mawid.auth;

/** Port for sending the OTP. Swap the logging one for Twilio, Vonage or a local SMS gateway. */
public interface SmsSender {

    void send(String phone, String message);
}
