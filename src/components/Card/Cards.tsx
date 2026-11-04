import React, { useMemo } from 'react';
import { Text, View } from 'react-native';
import { useSharedValue } from 'react-native-reanimated';
import Carousel from 'react-native-reanimated-carousel';
import { WIDTH } from '../../helpers/demensions';
import { useAppSelector } from '../../hooks/useAppSelector';
import { selectArticles } from '../../selectors/articleSelectors';
import { CardItem } from './CardItem/CardItem';
import { styles } from './CardsStyle';
import { PaginationItem } from './PaginationItem/PaginationItem';

export const Cards = () => {
  const articles = useAppSelector(selectArticles);
  const progressValue = useSharedValue<number>(0);

  const countArticles = useMemo(() => {
    return articles.length > 0;
  }, []);

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>News</Text>
      </View>
      <View style={styles.content}>
        {!countArticles && (
          <CardItem
            {...{
              title: 'Could not load news',
              image: '',
              slug: '',
              description: '',
              created_at: 'Check your internet connection',
            }}
          />
        )}
        {countArticles && (
          <Carousel
            loop
            width={WIDTH}
            height={200}
            pagingEnabled={false}
            snapEnabled={true}
            data={articles}
            scrollAnimationDuration={1200}
            mode="parallax"
            onProgressChange={(_, absoluteProgress) =>
              (progressValue.value = absoluteProgress)
            }
            modeConfig={{
              parallaxScrollingScale: 0.85,
              parallaxScrollingOffset: 75,
            }}
            renderItem={({ index }) => <CardItem {...articles[index]} />}
          />
        )}
        {!!progressValue && (
          <View style={styles.pagination}>
            {articles.map((_, index) => {
              return (
                <PaginationItem
                  backgroundColor={'#6b8afd'}
                  animValue={progressValue}
                  index={index}
                  key={index}
                  isRotate={false}
                  length={articles.length}
                />
              );
            })}
          </View>
        )}
      </View>
    </View>
  );
};
