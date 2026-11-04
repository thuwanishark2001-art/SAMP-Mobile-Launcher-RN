import { LINK_FORUM_HELP } from '@env';
import React from 'react';
import { Image, ImageBackground, Linking, Text, View } from 'react-native';
import Snow from 'react-native-snowflakes';
import {
  appBackground,
  appBackgroundNew,
  appLogoImg,
} from '../../assets/images';
import { useAppSelector } from '../../hooks/useAppSelector';
import { selectModeType } from '../../selectors/settingSelectors';
import { styles } from '../../styles/LoaderStyle';

type LoaderContainerType = {
  children: React.ReactNode;
};

export const LoaderContainer = React.memo((props: LoaderContainerType) => {
  const isSnow = useAppSelector(selectModeType);

  const supportHandler = React.useCallback(async () => {
    await Linking.openURL(LINK_FORUM_HELP);
  }, []);

  return (
    <View style={styles.container}>
      <ImageBackground
        style={styles.imageBackground}
        blurRadius={isSnow === 1 ? 5 : 10}
        imageStyle={{ opacity: 0.3 }}
        source={isSnow === 1 ? appBackgroundNew : appBackground}>
        <View style={styles.wrapper}>
          <View style={styles.logoWrapper}>
            <Image style={styles.logo} source={appLogoImg} />
          </View>
          <View style={styles.body}>
            <View
              style={{
                flex: 1,
                justifyContent: 'center',
                width: '100%',
              }}>
              {props.children}
            </View>
          </View>
          <View style={styles.footer}>
            <Text style={styles.description}>
              <Text style={styles.accent}>Attention!</Text> DO NOT MINIMIZE OR
              CLOSE{'\n'}
              THE APP UNTIL IT HAS FULLY STARTED{'\n'}
              If you run into problems, please{'\n'} contact{' '}
              <Text onPress={supportHandler} style={styles.link}>
                Technical support
              </Text>
            </Text>
          </View>
        </View>
      </ImageBackground>
      {isSnow === 1 && (
        <Snow fullScreen snowflakesCount={100} fallSpeed="medium" />
        // <Snow fullScreen snowflakesCount={100} fallSpeed="medium" />
      )}
    </View>
  );
});
