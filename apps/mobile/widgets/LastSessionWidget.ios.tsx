import { HStack, Text, VStack } from '@expo/ui/swift-ui';
import {
  font,
  foregroundStyle,
  padding,
} from '@expo/ui/swift-ui/modifiers';
import { createWidget, type WidgetEnvironment } from 'expo-widgets';

export type LastSessionProps = {
  location: string;
  costLabel: string;
  energyLabel: string;
  dateLabel: string;
};

const LastSessionLayout = (
  props: LastSessionProps,
  environment: WidgetEnvironment,
) => {
  'widget';

  const accent = environment.colorScheme === 'dark' ? '#00A3FF' : '#0077B8';
  const primary = environment.colorScheme === 'dark' ? '#F4F7FA' : '#0B1C2C';
  const secondary = environment.colorScheme === 'dark' ? '#9BB0C3' : '#5A7188';

  return (
    <VStack alignment="leading" modifiers={[padding({ all: 12 })]}>
      <Text modifiers={[font({ size: 11 }), foregroundStyle(secondary)]}>
        Last session
      </Text>
      <Text
        modifiers={[font({ size: 15, weight: 'bold' }), foregroundStyle(primary)]}
      >
        {props.location}
      </Text>
      <HStack>
        <Text modifiers={[font({ size: 13, weight: 'semibold' }), foregroundStyle(accent)]}>
          {props.costLabel}
        </Text>
        <Text modifiers={[font({ size: 12 }), foregroundStyle(secondary)]}>
          · {props.energyLabel}
        </Text>
      </HStack>
      <Text modifiers={[font({ size: 11 }), foregroundStyle(secondary)]}>
        {props.dateLabel}
      </Text>
    </VStack>
  );
};

const LastSessionWidget = createWidget('LastSessionWidget', LastSessionLayout);

export default LastSessionWidget;
