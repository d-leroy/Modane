package fr.cea.modane.generator

import fr.cea.modane.modane.SimpleType
import fr.cea.modane.modane.Variable

class VariableExtensions {
	
	static def getMultiplicity(Variable it) { return type.multiplicity }
	
	static def getMultiplicity(SimpleType it)
	{
		val result = switch (it)
		{
			case ARRAY_BOOLEAN,
			case ARRAY_INTEGER,
			case ARRAY_INT32,
			case ARRAY_INT64,
			case ARRAY_STRING,
			case ARRAY_REAL,
			case ARRAY_REAL2,
			case ARRAY_REAL3,
			case ARRAY_REAL2X2,
			case ARRAY_REAL3X3:
				'Array'
			case ARRAY2_BOOLEAN,
			case ARRAY2_INTEGER,
			case ARRAY2_INT32,
			case ARRAY2_INT64,
			case ARRAY2_REAL,
			case ARRAY2_REAL2,
			case ARRAY2_REAL3,
			case ARRAY2_REAL2X2,
			case ARRAY2_REAL3X3:
				'Array2'
			default:
				'Scalar'
		}
		
		return result
	}
	
	static def getTypeName(SimpleType it)
	{
		val result = switch (it)
		{
			case ARRAY_BOOLEAN,
			case ARRAY2_BOOLEAN: SimpleType::BOOLEAN.getName
			case ARRAY_STRING: SimpleType::STRING.getName
			case ARRAY_INTEGER,
			case ARRAY2_INTEGER: SimpleType::INTEGER.getName
			case ARRAY_INT32,
			case ARRAY2_INT32: SimpleType::INT32.getName
			case ARRAY_INT64,
			case ARRAY2_INT64: SimpleType::INT64.getName
			case ARRAY_REAL,
			case ARRAY2_REAL: SimpleType::REAL.getName
			case ARRAY_REAL2,
			case ARRAY2_REAL2: SimpleType::REAL2.getName
			case ARRAY_REAL3,
			case ARRAY2_REAL3: SimpleType::REAL3.getName
			case ARRAY_REAL2X2,
			case ARRAY2_REAL2X2: SimpleType::REAL2X2.getName
			case ARRAY_REAL3X3,
			case ARRAY2_REAL3X3: SimpleType::REAL3X3.getName
			default: getName
		}
		
		return result
	}
	
}