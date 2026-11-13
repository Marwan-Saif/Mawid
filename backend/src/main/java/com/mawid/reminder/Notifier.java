package com.mawid.reminder;

/** Port for customer messages. The default logs; plug in WhatsApp Cloud API or SMS for production. */
public interface Notifier {

    void send(String phone, String message);
}
