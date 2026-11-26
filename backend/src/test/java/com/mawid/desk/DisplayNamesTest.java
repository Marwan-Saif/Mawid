package com.mawid.desk;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class DisplayNamesTest {

    @Test
    void shortensFamilyNames() {
        assertThat(DisplayNames.forScreen("يوسف النجار")).isEqualTo("يوسف ن.");
        assertThat(DisplayNames.forScreen("Omar Saleh Haddad")).isEqualTo("Omar S.");
    }

    @Test
    void keepsKunyasAndAlreadyShortNames() {
        assertThat(DisplayNames.forScreen("أبو سامي")).isEqualTo("أبو سامي");
        assertThat(DisplayNames.forScreen("مريم ع.")).isEqualTo("مريم ع.");
        assertThat(DisplayNames.forScreen("ريم")).isEqualTo("ريم");
        assertThat(DisplayNames.forScreen("  ")).isNull();
    }

    @Test
    void readsCodesFromLinksAndRawText() {
        assertThat(DeskService.extractCode("https://mawid.app/c/k7q2m9xw3a")).isEqualTo("K7Q2M9XW3A");
        assertThat(DeskService.extractCode("mawid:K7Q2M9XW3A")).isEqualTo("K7Q2M9XW3A");
        assertThat(DeskService.extractCode(" K7Q2M9XW3A ")).isEqualTo("K7Q2M9XW3A");
    }
}
