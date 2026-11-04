import { NativeStackScreenProps } from '@react-navigation/native-stack';
import React, { useCallback } from 'react';
import { Text, View } from 'react-native';
import { LoaderContainer } from '../components';
import { ModeItem } from '../components/Mode/ModeItem';
import { useAppDispatch } from '../hooks/useAppDispatch';
import { styles } from '../styles/ModeStyle';
import { fetchModeSetting } from '../thunks/settingsThunks';
import * as Images from './../assets/images';

type InitiationScreenType = NativeStackScreenProps<any>;

export const ModeScreen = React.memo(({ navigation }: InitiationScreenType) => {
  const dispatch = useAppDispatch();

  const onPress = useCallback((id: number) => {
    dispatch(fetchModeSetting(id));
    return navigation.replace('Initiation');
  }, []);

  return (
    <LoaderContainer>
      <Text style={styles.titleSub}>Choose a map</Text>
      <View style={styles.body}>
        <ModeItem
          id={0}
          onPress={onPress}
          text="Standard map"
          image={Images.Default}
          color={['#a4956e99', '#f5422a60']}
        />
        <ModeItem
          id={1}
          onPress={onPress}
          text="Winter map"
          image={Images.Snow}
          color={['#88effc99', '#6e2af560']}
        />
      </View>
    </LoaderContainer>
  );
});
